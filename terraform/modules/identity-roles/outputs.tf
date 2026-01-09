/*
 * Script Name  : outputs.tf
 * Project Name : Primus
 * Description  : Exports key identifiers of the created IAM Role.
 *                These outputs are used to attach policies or reference the role in other resources.
 * Scope        : Module (IAM Role)
 *
 * Output Details:
 * - Role ARN          : The Amazon Resource Name, used for cross-account access or resource policies.
 * - Role Name         : The friendly name, used for policy attachments.
 * - Role ID           : The unique identifier.
 */

output "iam_role_arn" {
  description = "The Amazon Resource Name (ARN) of the IAM role."
  value       = aws_iam_role.main.arn
}

output "iam_role_name" {
  description = "The name of the IAM role."
  value       = aws_iam_role.main.name
}

output "iam_role_id" {
  description = "The stable and unique ID of the IAM role."
  value       = aws_iam_role.main.id
}
