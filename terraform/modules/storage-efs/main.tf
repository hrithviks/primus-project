/*
 * Script Name  : main.tf
 * Project Name : Primus
 * Description  : Defines the EFS file system and mount targets.
 * Scope        : Module (Storage/EFS)
 */

resource "aws_efs_file_system" "main" {
  creation_token = var.efs_creation_token
  encrypted      = var.efs_encrypted
  kms_key_id     = var.efs_kms_key_id

  tags = merge(
    {
      Name = var.efs_name
    },
    var.efs_tags
  )
}

resource "aws_efs_mount_target" "main" {
  count           = length(var.efs_subnet_ids)
  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.efs_subnet_ids[count.index]
  security_groups = var.efs_security_group_ids
}
