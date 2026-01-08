/*
 * Script Name  : outputs.tf
 * Project Name : Primus
 * Description  : Defines the output configuration for the Terraform project.
 * Scope        : Module (Security Groups)
 */

output "sg_id" {
  value = aws_security_group.main.id
}

output "sg_arn" {
  value = aws_security_group.main.arn
}
