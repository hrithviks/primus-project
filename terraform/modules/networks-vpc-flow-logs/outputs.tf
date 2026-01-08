/*
 * Script Name  : outputs.tf
 * Project Name : Primus
 * Description  : Output values for the VPC Flow Logs Module.
 * Scope        : Module (VPC Flow Logs)
 */

output "vpc_flow_log_group_name" {
  value = aws_cloudwatch_log_group.flow_log_main.name
}

output "vpc_flow_log_group_arn" {
  value = aws_cloudwatch_log_group.flow_log_main.arn
}

output "vpc_flow_log_encryption_key_arn" {
  value = module.vpc_flow_logs_key.kms_key_arn
}

output "vpc_flow_log_encryption_key_id" {
  value = module.vpc_flow_logs_key.kms_key_id
}

output "vpc_flow_log_iam_role_name" {
  value = module.iam_flow_log_role.iam_role_name
}

output "vpc_flow_log_iam_role_arn" {
  value = module.iam_flow_log_role.iam_role_arn
}
