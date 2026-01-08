/*
 * Script Name  : main.tf
 * Project Name : Primus
 * Description  : Root configuration for EKS platform
 * Scope        : Root
 */

locals {
  RESOURCE_PREFIX = "${var.main_project_prefix}-${var.main_eks_env}"

  # Resource Names
  VPC_FLOW_LOG_NAME = "${local.RESOURCE_PREFIX}-vpc-flow-logs"
}

/*
* ---------------------------------------------------------
* VPC FLOW LOG - CLOUDWATCH GROUP, KMS, IAM ROLE AND POLICY
* ---------------------------------------------------------
* Create a VPC flow log group - Handles creation of an encrypted (CMK) log group
* with IAM policies attached to a custom role for access.
*/

module "main_vpc_flow_logs" {
  source = "../modules/networks-vpc-flow-logs"

  vpc_flow_log_group_name        = local.VPC_FLOW_LOG_NAME
  vpc_flow_log_retention_in_days = 7
  vpc_flow_log_prefix            = local.RESOURCE_PREFIX
  vpc_flow_log_kms_description   = "CMK for encrypting EKS VPC Flow Logs"
  vpc_flow_log_kms_alias         = "alias/${local.RESOURCE_PREFIX}-vpc-log-enc"
}

/*
* ----------------------------------------------------------
* VPC MAIN RESOURCES - SUBNETS, GATEWAYS, ROUTES TABLES etc.
* ----------------------------------------------------------
* Create a VPC to host the ECS cluster, along with all associated resources for 
* networking - Internet Gateway, NAT Gateway, Route
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
