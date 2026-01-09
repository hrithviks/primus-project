/*
 * Script Name  : outputs.tf
 * Project Name : Primus
 * Description  : Exports key identifiers of the created IAM Policy.
 *                These outputs are essential for attaching the policy to other entities
 *                (users, groups, roles) outside of this module or for auditing purposes.
 * Scope        : Module (IAM/Policy)
 *
 * Output Details:
 * - Policy ARN        : The Amazon Resource Name, required for attachments.
 * - Policy Name       : The friendly name of the policy.
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
