/*
 * Script Name  : main-ecs.tf
 * Project Name : Primus
 * Description  : Provisions the core ECS Cluster and shared infrastructure dependencies.
 *                This includes the container orchestration layer, persistent storage,
 *                service discovery, and centralized logging.
 *
 * ------------------------
 * Architectural Decisions:
 * ------------------------
 * - Container Orchestration : AWS ECS (Fargate) is selected for serverless container management,
 *                             removing the operational overhead of managing EC2 instances.
 * - Persistent Storage      : Amazon EFS provides scalable, persistent storage for stateful
 *                             workloads (OpenSearch), ensuring data survives container restarts.
 * - Service Discovery       : AWS Cloud Map is integrated to enable service-to-service communication
 *                             via private DNS, abstracting dynamic IP addresses.
 * - Security & Compliance   :
 *     - Encryption at Rest  : A dedicated KMS Customer Managed Key (CMK) encrypts EFS volumes
 *                             and CloudWatch Log Groups.
 *     - Network Isolation   : ECS tasks are deployed in private subnets with restricted Security Groups.
 *
 * ---------------
 * Best Practices:
 * ---------------
 * - Least Privilege         : EFS Access Points enforce specific POSIX user/group IDs (UID/GID 1000),
 *                             preventing root access to the file system.
 * - Observability           : Container Insights is enabled on the cluster for granular metrics.
 */

/*
 * -------------------------------
 * ENCRYPTION INFRASTRUCTURE (KMS)
 * -------------------------------
 * Purpose:
 *   Establishes a centralized Customer Managed Key (CMK) for encrypting data at rest.
 *
 * Scope:
 *   - CloudWatch Log Groups
 *   - EFS File Systems
 *
 * Implementation Details:
 *   - Algorithm : Symmetric AES-256 key.
 *   - Policy    : Grants administrative permissions to the root account and usage permissions
 *                 to CloudWatch Logs and EFS services via IAM roles/policies.
 *
 * Design Rationale:
 *   - Compliance : Many security standards (PCI-DSS, HIPAA etc.) require Customer Managed Keys (CMK)
 *                  rather than AWS Managed Keys to ensure full control over key lifecycle,
 *                  rotation policies, and deletion.
 */

module "storage_kms_key" {
  source = "../modules/security-kms"

  kms_description             = local.KMS_STORAGE_DESC
  kms_deletion_window_in_days = 7
  kms_enable_key_rotation     = true
  kms_key_alias               = local.KMS_STORAGE_ALIAS
  kms_admin_account_id        = local.AWS_ACCOUNT_ID
  kms_account_region          = local.AWS_REGION
}

/*
 * --------------------------------
 * CENTRALIZED LOGGING (CLOUDWATCH)
 * --------------------------------
 * Purpose:
 *   Aggregates stdout/stderr logs from all ECS containers into a single Log Group.
 *
 * Implementation Details:
 *   - Storage    : Logs are stored in a regional CloudWatch Log Group.
 *   - Encryption : Server-side encryption is enforced using the KMS CMK.
 *   - Retention  : Configured to expire after 7 days to manage storage costs.
 *
 * Design Rationale:
 *   - Ephemeral Nature : Containers are transient; local logs are lost upon termination.
 *                        CloudWatch provides durable, searchable storage for debugging.
 *   - Security         : Encrypted storage protects sensitive data potentially leaked in logs.
 */

resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = local.ECS_LOG_GROUP_NAME
  retention_in_days = 7
  kms_key_id        = module.storage_kms_key.kms_key_arn
}

/*
 * ------------------------
 * PERSISTENT STORAGE (EFS)
 * ------------------------
 * Purpose:
 *   Provides a shared, elastic file system for stateful services (OpenSearch).
 *
 * Design Rationale:
 *   - Persistence : OpenSearch is stateful; data must survive container restarts or replacements.
 *   - Scalability : EFS grows automatically, removing the need to provision EBS volume sizes.
 */

# -----------------
# EFS File System
# -----------------
/*
 * Implementation Details:
 *   - File System : Regional EFS file system (Standard class) for high availability across AZs.
 *   - Encryption  : Data at rest is encrypted using the KMS CMK.
 *   - Mounts      : Mount targets are created in each private subnet.
 */
module "efs" {
  source = "../modules/storage-efs"

  efs_name               = local.EFS_NAME
  efs_creation_token     = local.EFS_NAME
  efs_encrypted          = true
  efs_kms_key_id         = module.storage_kms_key.kms_key_arn
  efs_subnet_ids         = module.main_vpc.private_subnet_ids
  efs_security_group_ids = [module.efs_sg.sg_id]
}

# ------------------
# EFS Access Point
# ------------------
/*
 * Implementation Details:
 *   - Identity Override : Enforces POSIX UID/GID 1000 for all connections through this access point.
 *   - Root Directory    : Restricts access to a specific directory (`/opensearch-data`) and
 *                         automatically creates it with correct permissions if missing.
 *
 * Design Rationale:
 *   - Security : Decouples the container's internal user (often root) from the file system permissions.
 *                Prevents a compromised container from accessing other data on the shared file system.
 */
resource "aws_efs_access_point" "opensearch" {
  file_system_id = module.efs.efs_id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/opensearch-data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }
}

/*
 * -----------------------------
 * SERVICE DISCOVERY (CLOUD MAP)
 * -----------------------------
 * Purpose:
 *   Enables internal DNS resolution for microservices.
 *
 * Design Rationale:
 *   - Dynamic Addressing : In ECS Fargate, tasks receive new private IPs upon every restart.
 *                          Hardcoding IPs is impossible; DNS-based discovery abstracts this complexity.
 */

# -------------------------------
# Cloud Map Private DNS Namespace
# -------------------------------
/*
 * Implementation Details:
 *   - Hosted Zone : Creates a private Route 53 hosted zone associated with the VPC.
 *   - Resolution  : Services within the VPC can resolve names like `opensearch.local` to private IPs.
 */
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = local.CLOUDMAP_NAMESPACE_NAME
  description = local.CLOUDMAP_NAMESPACE_DESC
  vpc         = module.main_vpc.vpc_id
}

# -----------------
# Cloud Map Service
# -----------------
/*
 * Implementation Details:
 *   - Registry : Creates a service entry in the Cloud Map namespace for each ECS service.
 *   - DNS Type : Configures 'A' records with a short TTL (10s) for rapid propagation of changes.
 *
 * Design Rationale:
 *   - Automation : ECS automatically registers/deregisters task IPs as they scale up or down,
 *                  ensuring the DNS record always points to healthy instances.
 */
resource "aws_service_discovery_service" "main" {
  for_each = local.ECS_SERVICES

  name = each.value

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id
    dns_records {
      ttl  = 10
      type = "A"
    }
  }
}

# --------------------
# ECS CLUSTER RESOURCE
# --------------------
/*
 * Implementation Details:
 *   - Control Plane : Provisions a regional ECS cluster to manage task scheduling and state.
 *   - Monitoring    : 'containerInsights' is explicitly enabled.
 *
 * Design Rationale:
 *   - Serverless : Fargate launch type is used (implied by task definitions), removing the
 *                  overhead of patching and scaling EC2 instances.
 *   - Observability : Container Insights provides granular metrics (CPU, Memory, Network)
 *                     aggregated at the task and service level without custom agents.
 */
resource "aws_ecs_cluster" "main" {
  name = local.ECS_CLUSTER_NAME

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = local.ECS_CLUSTER_NAME
  }
}
