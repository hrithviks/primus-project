/*
 * Script Name  : main-vpc.tf
 * Project Name : Primus
 * Description  : Provisions the foundational networking infrastructure for the ECS cluster.
 *                This configuration establishes a secure, high-availability Virtual Private Cloud (VPC)
 *                spanning multiple Availability Zones.
 *
 * -----------------
 * Design Rationale:
 * -----------------
 * - Network Isolation : A dedicated VPC isolates the observability stack from other workloads.
 * - High Availability : Subnets are distributed across three Availability Zones (AZs) to ensure
 *                       resilience against data center failures.
 * - Security Layers   : A public/private subnet architecture is employed. Public subnets host
 *                       load balancers, while private subnets host the application workloads (ECS tasks),
 *                       preventing direct internet exposure.
 * - Observability     : VPC Flow Logs are enabled to capture IP traffic information for audit
 *                       and security analysis.
 *
 * ---------------
 * Best Practices:
 * ---------------
 * - Encryption        : Flow logs are encrypted at rest using a Customer Managed Key (CMK).
 * - Least Privilege   : Dedicated IAM roles are generated for flow log delivery.
 *
 * ---------------------------------------------------------------------------
 * Recommended Scalability & Cost Optimization (Private Connectivity Pattern):
 * ---------------------------------------------------------------------------
 * The current design is driven by the need for simplicity, for a demo implementation.
 * To minimize NAT Gateway data processing costs and ensure traffic remains on the AWS private
 * network, the following steps should be implemented for dependent AWS services:
 *
 * 1. Gateway Endpoints (e.g., S3, DynamoDB):
 *    - Route Tables   : Update private route tables to target the Gateway Endpoint for the
 *                       specific service region.
 *    - Security Groups: Configure ECS Task security groups to allow outbound traffic to the
 *                       AWS-managed Prefix List ID (e.g., pl-xxxxxx) associated with the service.
 *
 * 2. Interface Endpoints (e.g., ECR, CloudWatch, Secrets Manager):
 *    - Provisioning   : Deploy interface endpoints within the private subnets.
 *    - Security Groups: Create a dedicated security group for the endpoints allowing HTTPS (443)
 *                       ingress from the ECS Task Security Group.
 *    - DNS Resolution : Enable Private DNS to automatically resolve service hostnames to private IPs.
 */

/*
 * ---------------------------
 * VPC FLOW LOGS CONFIGURATION
 * ---------------------------
 * Purpose:
 *   Captures information about the IP traffic going to and from network interfaces
 *   in the VPC. This is critical for security monitoring and troubleshooting.
 *
 * Implementation Details:
 *   - Destination : CloudWatch Logs for centralized analysis.
 *   - Encryption  : Uses a dedicated KMS Customer Managed Key (CMK) for compliance.
 *   - Retention   : Logs are retained for 7 days to balance cost and audit requirements.
 *
 * Design Rationale:
 *   - Compliance  : Encrypted logging provides an immutable audit trail required for security standards.
 */

module "main_vpc_flow_logs" {
  source = "../modules/networks-vpc-flow-logs"

  vpc_flow_log_group_name        = local.VPC_FLOW_LOG_NAME
  vpc_flow_log_prefix            = local.RESOURCE_PREFIX
  vpc_flow_log_retention_in_days = 7
  vpc_flow_log_kms_description   = local.VPC_FLOW_LOG_DESC
  vpc_flow_log_kms_alias         = "alias/${local.RESOURCE_PREFIX}-vpc-log-enc"
}

/*
 * ------------------
 * MAIN VPC RESOURCES
 * ------------------
 * Purpose:
 *   Deploys the core network topology including subnets, route tables, and gateways.
 *
 * Implementation Details:
 *   - CIDR Block      : Defined via variables to allow flexible sizing per environment.
 *   - Public Subnets  : Host the Application Load Balancer (ALB) and NAT Gateways.
 *   - Private Subnets : Host ECS Tasks and EFS Mount Targets. Outbound internet access
 *                       is provided via NAT Gateways in the public subnets.
 *
 * Design Rationale:
 *   - Security Layers : Public/Private subnet split ensures that backend services are not directly exposed.
 */

module "main_vpc" {
  source = "../modules/networks-vpc-main"

  # VPC configuration
  vpc_resource_prefix      = local.RESOURCE_PREFIX
  vpc_cidr                 = var.network_vpc_cidr
  vpc_public_subnets_cidr  = var.network_public_subnets_cidr
  vpc_private_subnets_cidr = var.network_private_subnets_cidr
  vpc_availability_zones   = var.network_availability_zones

  # VPC flow log configuration
  vpc_flow_log_destination_arn = module.main_vpc_flow_logs.vpc_flow_log_group_arn
  vpc_flow_log_iam_role_arn    = module.main_vpc_flow_logs.vpc_flow_log_iam_role_arn
}
