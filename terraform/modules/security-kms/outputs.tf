/*
 * Script Name  : outputs.tf
 * Project Name : Primus
 * Description  : Output values for the KMS module.
 * Scope        : Module (KMS)
 */

output "kms_key_arn" {
  value = aws_kms_key.main.arn
}

output "kms_key_id" {
  value = aws_kms_key.main.id
}
