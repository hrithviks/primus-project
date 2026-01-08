/*
 * Script Name  : main.tf
 * Project Name : Primus
 * Description  : Defines the output configuration for the Terraform project.
 * Scope        : Module (IAM/Policy)
 */

output "iam_policy_name" {
  value = var.iam_policy_name
}

output "iam_policy_description" {
  value = var.iam_policy_description
}

output "iam_policy_arn" {
  value = aws_iam_policy.main.arn
}
