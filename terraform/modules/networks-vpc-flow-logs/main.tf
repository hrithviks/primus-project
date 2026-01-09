/*
 * Script Name  : main.tf
 * Project Name : Primus
 * Description  : Main configuration for the VPC Flow Logs Module.
 * Scope        : Module (VPC Flow Logs)
 */

# Retrieves the current account details
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

/*
 * -----------------------
 * KMS KEY - VPC FLOW LOGS
 * -----------------------
 * Invokes the KMS module to create a new CMK for encrypting VPC Flow Logs.
 */
module "vpc_flow_logs_key" {
  source = "../security-kms"

  kms_description             = var.vpc_flow_log_kms_description
  kms_deletion_window_in_days = var.vpc_flow_log_deletion_window
  kms_enable_key_rotation     = var.vpc_flow_log_enable_key_rotation
  kms_key_alias               = "alias/${var.vpc_flow_log_prefix}-vpc-log-enc"
  kms_admin_account_id        = data.aws_caller_identity.current.account_id
  kms_account_region          = data.aws_region.current.id
}

/*
 * --------------------
 * CLOUDWATCH LOG GROUP
 * --------------------
 * Creates a CloudWatch Log Group for VPC Flow Logs.
 */
resource "aws_cloudwatch_log_group" "flow_log_main" {
  name              = var.vpc_flow_log_group_name
  retention_in_days = var.vpc_flow_log_retention_in_days
  kms_key_id        = module.vpc_flow_logs_key.kms_key_arn
}

/*
 * ----------------------------------------------
 * IAM ROLES AND POLICIES TO ACCESS VPC FLOW LOGS
 * ----------------------------------------------
 * Creates an IAM Role for VPC Flow Logs and attaches a custom policy to access VPC Flow Logs.
 */

# Defines locals to populate the IAM policies
locals {

  # Trust Policy for IAM Role for VPC Flow Logs
  vpc_flow_log_iam_role_trust_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  }

  # Permission Policy for IAM Role for VPC Flow Logs
  vpc_flow_log_iam_role_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = aws_cloudwatch_log_group.flow_log_main.arn
      }
    ]
  }
}

# Invokes IAM roles module to create a new IAM role for VPC Flow Logs
module "iam_flow_log_role" {
  source = "../identity-roles"

  iam_role_name         = "${var.vpc_flow_log_prefix}-vpc-flow-log-role"
  iam_role_description  = "The IAM role for VPC Flow Log ${var.vpc_flow_log_prefix}"
  iam_role_trust_policy = jsonencode(local.vpc_flow_log_iam_role_trust_policy)
}

# Invokes IAM policies module to create a new IAM policy for VPC Flow Logs and attach to the role
module "iam_flow_log_policy" {
  source = "../identity-policies"

  iam_policy_name                 = "${var.vpc_flow_log_prefix}-vpc-flow-log-policy"
  iam_policy_description          = "The IAM policy for VPC Flow Log ${var.vpc_flow_log_prefix}"
  iam_policy_document             = jsonencode(local.vpc_flow_log_iam_role_policy)
  iam_policy_attachment_role_name = module.iam_flow_log_role.iam_role_name
}
