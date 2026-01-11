/*
 * Script Name: main-opensearch.tf
 * Project Name: Primus
 * Description: Provisions the OpenSearch service on ECS.
 * OpenSearch acts as the central data store and search engine for the
 * observability stack, indexing logs ingested by Logstash.
 *
 * -----------------
 * Design Rationale:
 * -----------------
 * - Stateful Architecture: Unlike the stateless Dashboards and Logstash services, OpenSearch
 * requires persistent storage. Amazon EFS is integrated to ensure
 * data durability across container restarts.
 * - Security First: Sensitive credentials (admin password) are generated dynamically
 * and stored in AWS Secrets Manager, injected only at runtime.
 * - Network Isolation: The service resides in private subnets, accessible only via the
 * internal service mesh or the specific ALB target group for API access.
 */

/*
 * ------------------
 * SECRETS MANAGEMENT
 * ------------------
 * Purpose:
 *   Generates and securely stores the initial administrative credentials.
 *
 * Implementation Details:
 *   - Generation: A cryptographically strong random password is created during provisioning.
 *   - Storage: The password is stored in AWS Secrets Manager, encrypted with the KMS CMK.
 *
 * Design Rationale:
 *   - Zero Trust: Prevents hardcoding sensitive credentials in Terraform state (partially)
 *   or source code. ECS retrieves the secret directly at runtime.
 */

/*
Moving Key and Secret to central management outside of Terraform, due to errors
during apply phase

resource "random_password" "opensearch_admin_password" {
  length           = 16
  special          = true
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "_%@"
}

# NOTE:
# Force delete the secret using AWS CLI before re-creating.
# aws secretsmanager delete-secret --secret-id "Secret_ID" --force-delete-without-recovery
resource "aws_secretsmanager_secret" "opensearch_admin_password" {
  name        = "${local.RESOURCE_PREFIX}-os-admin-pswd"
  description = "Initial admin password for OpenSearch"
  kms_key_id  = module.storage_kms_key.kms_key_arn
}

resource "aws_secretsmanager_secret_version" "opensearch_admin_password" {
  secret_id     = aws_secretsmanager_secret.opensearch_admin_password.id
  secret_string = random_password.opensearch_admin_password.result
}
*/

# Import existing Key and Secret
data "aws_kms_key" "opensearch_secrets_key" {
  key_id = var.ecs_os_secret_enc_id
}

data "aws_secretsmanager_secret" "opensearch_admin_password" {
  name = var.ecs_os_secret_name
}

/*
 * ------------------
 * IAM EXECUTION ROLE
 * ------------------
 * Purpose:
 *   Grants the ECS agent permission to bootstrap the container.
 *
 * Implementation Details:
 *   - Permissions: Standard ECR/CloudWatch access, plus specific permissions to retrieve
 *   the 'opensearch-admin-password' from Secrets Manager and decrypt it via KMS.
 *
 * Design Rationale:
 *   - Secure Injection: The execution role handles secret retrieval, keeping the sensitive
 *   value out of the task definition environment variables.
 */

module "ecs_opensearch_exec_role" {
  source = "../modules/identity-roles"

  iam_role_name        = local.ECS_OS_EXEC_ROLE_NAME
  iam_role_description = local.ECS_OS_EXEC_ROLE_DESC

  iam_role_trust_policy = templatefile("./templates/iam-trust-policy.json", { SERVICE_NAME = "ecs-tasks.amazonaws.com" })
}

module "ecs_opensearch_exec_role_policy" {
  source = "../modules/identity-policies"

  iam_policy_name        = local.ECS_OS_EXEC_POLICY_NAME
  iam_policy_description = local.ECS_OS_EXEC_POLICY_DESC

  iam_policy_document = templatefile("./templates/opensearch/ecs-os-execution-role.json", {
    # Managed Secret and Key
    SECRET_ARN  = data.aws_secretsmanager_secret.opensearch_admin_password.arn
    KMS_KEY_ARN = data.aws_kms_key.opensearch_secrets_key.arn
  })

  iam_policy_attachment_role_name = module.ecs_opensearch_exec_role.iam_role_name
}

/*
 * -------------
 * IAM TASK ROLE
 * -------------
 * Purpose:
 *   Grants the OpenSearch application permissions to interact with AWS services.
 *
 * Design Rationale:
 *   - Granular Access: Policies are scoped strictly to resources required for index management
 *   (e.g., S3 for snapshots, if configured) or internal cluster operations.
 */

module "ecs_opensearch_task_role" {
  source = "../modules/identity-roles"

  iam_role_name        = local.ECS_OS_TASK_ROLE_NAME
  iam_role_description = local.ECS_OS_TASK_ROLE_DESC

  iam_role_trust_policy = templatefile("./templates/iam-trust-policy.json", {
    SERVICE_NAME = "ecs-tasks.amazonaws.com"
  })
}

module "ecs_opensearch_task_role_policy" {
  source = "../modules/identity-policies"

  iam_policy_name        = local.ECS_OS_TASK_POLICY_NAME
  iam_policy_description = local.ECS_OS_TASK_POLICY_DESC

  iam_policy_document = templatefile("./templates/opensearch/ecs-os-task-role.json", {
    RESOURCE_PREFIX = local.RESOURCE_PREFIX
    AWS_REGION      = local.AWS_REGION
    AWS_ACCOUNT_ID  = local.AWS_ACCOUNT_ID
  })

  iam_policy_attachment_role_name = module.ecs_opensearch_task_role.iam_role_name
}

/*
 * --------------------
 * ECS TASK AND SERVICE
 * --------------------
 * Purpose:
 *   Defines the runtime configuration for the OpenSearch stateful container.
 *
 * Implementation Details:
 *   - Storage Integration: Mounts the EFS Access Point to `/usr/share/opensearch/data`.
 *   - Resource Allocation: Provisioned with higher CPU/Memory (1 vCPU / 2GB) to handle indexing loads.
 *   - Networking: Exposed on port 9200 (API) and 9600 (Performance Analyzer).
 *
 * Design Rationale:
 *   - Data Durability: EFS provides a POSIX-compliant file system that persists data
 *   independent of the container lifecycle.
 */

locals {
  ADMIN_PASSWORD_ARN = "${data.aws_secretsmanager_secret.opensearch_admin_password.arn}:OPENSEARCH_INITIAL_ADMIN_PASSWORD::"
}

module "opensearch" {
  source = "../modules/ecs-service"

  ecs_task_family_name                  = "${local.RESOURCE_PREFIX}-opensearch-task"
  ecs_name                              = local.ECS_OPENSEARCH_NAME
  ecs_task_cpu                          = 1024
  ecs_task_memory                       = 2048
  ecs_task_execution_role_arn           = module.ecs_opensearch_exec_role.iam_role_arn
  ecs_task_role_arn                     = module.ecs_opensearch_task_role.iam_role_arn
  ecs_cluster_id                        = aws_ecs_cluster.main.id
  ecs_subnet_ids                        = module.main_vpc.private_subnet_ids
  ecs_security_group_ids                = [module.opensearch_sg.sg_id]
  ecs_service_registry_arn              = aws_service_discovery_service.main["opensearch"].arn
  ecs_target_group_arn                  = aws_lb_target_group.opensearch.arn
  ecs_container_port                    = 9200
  ecs_health_check_grace_period_seconds = 300

  ecs_task_container_definitions = templatefile("templates/opensearch/ecs-os-container-defn.json", {
    NAME           = local.ECS_OPENSEARCH_NAME
    IMAGE          = "opensearchproject/opensearch:latest"
    LOG_GROUP      = aws_cloudwatch_log_group.ecs_log_group.name
    REGION         = local.AWS_REGION
    STREAM_PREFIX  = local.ECS_OPENSEARCH_NAME
    ADMIN_PSWD_ARN = local.ADMIN_PASSWORD_ARN
  })

  ecs_volume_config = {
    name            = "opensearch-data"
    file_system_id  = module.efs.efs_id
    root_directory  = "/"
    access_point_id = aws_efs_access_point.opensearch.id
  }
}
