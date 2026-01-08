/*
 * Script Name  : variables.tf
 * Project Name : Primus
 * Description  : Defines input variables for the EFS module.
 * Scope        : Module (Storage/EFS)
 */

variable "efs_name" {
  description = "Name of the EFS file system"
  type        = string
}

variable "efs_creation_token" {
  description = "A unique name used as reference when creating the Elastic File System"
  type        = string
}

variable "efs_encrypted" {
  description = "If true, the disk will be encrypted"
  type        = bool
  default     = true
}

variable "efs_kms_key_id" {
  description = "The ARN for the KMS encryption key"
  type        = string
  default     = null
}

variable "efs_subnet_ids" {
  description = "A list of subnet IDs to launch the mount targets in"
  type        = list(string)
}

variable "efs_security_group_ids" {
  description = "A list of security groups to apply to the mount targets"
  type        = list(string)
}

variable "efs_tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}
