/*
 * Script Name  : outputs.tf
 * Project Name : Primus
 * Description  : Outputs for the EFS module.
 * Scope        : Module (Storage/EFS)
 */

output "efs_id" {
  description = "The ID that identifies the file system"
  value       = aws_efs_file_system.main.id
}

output "efs_arn" {
  description = "The Amazon Resource Name (ARN) of the file system"
  value       = aws_efs_file_system.main.arn
}

output "efs_dns_name" {
  description = "The DNS name for the file system"
  value       = aws_efs_file_system.main.dns_name
}
