/*
 * Script Name: 01-main-vpc.tf
 * Project Name: Primus
 * Description: Provisions the networking foundation for the EKS cluster.
 * This includes the Virtual Private Cloud (VPC), subnets, gateways,
 * and routing tables required for cluster connectivity and isolation.
 *
 * ------------------------
 * Architectural Decisions:
 * ------------------------
 * - Network Isolation: Uses a VPC with public and private subnets across multiple Availability Zones
 * to ensure high availability and secure workload placement.
 * - Traffic Management: NAT Gateways are configured to allow private subnet instances to access
 * the internet (e.g., for updates) without exposing them to inbound traffic.
 * - Observability: VPC Flow Logs are enabled and encrypted to capture IP traffic information
 * for security auditing and troubleshooting.
 */

/*
 * --------------------------
 * VPC FLOW LOGS & ENCRYPTION
 * --------------------------
 * Purpose:
 *   Captures information about the IP traffic going to and from network interfaces in the VPC.
 *
 * Implementation Details:
 *   - Destination: CloudWatch Log Group.
 *   - Encryption: Logs are encrypted using a Customer Managed Key (CMK) via KMS.
 *   - Retention: Logs are retained for 7 days to balance visibility and cost.
 */

module "main_vpc_flow_logs" {
  source = "../modules/networks-vpc-flow-logs"

  vpc_flow_log_group_name        = local.VPC_FLOW_LOG_NAME
  vpc_flow_log_retention_in_days = 7
  vpc_flow_log_prefix            = local.RESOURCE_PREFIX
  vpc_flow_log_kms_description   = local.VPC_FLOW_LOG_DESC
  vpc_flow_log_kms_alias         = local.VPC_FLOW_LOG_KMS_ALIAS
}

/*
 * -----------------------
 * VPC CORE INFRASTRUCTURE
 * -----------------------
 * Purpose:
 *   Establishes the isolated network environment for the EKS cluster.
 *
 * Implementation Details:
 *   - Subnets: Public subnets for load balancers/NAT gateways; Private subnets for EKS nodes.
 *   - Routing: Route tables configured to route internet traffic via IGW (public) or NAT (private).
 *   - AZ Strategy: Distributes resources across 3 Availability Zones for fault tolerance.
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
