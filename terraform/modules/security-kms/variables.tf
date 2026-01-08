/*
 * Script Name  : variables.tf
 * Project Name : Primus
 * Description  : Input variables for the KMS module.
 * Scope        : Module (KMS)
 */

variable "kms_description" {
  type        = string
  description = "The description for the KMS Key"
}

variable "kms_deletion_window_in_days" {
  type        = number
  description = "The deletion window in days"
}

variable "kms_enable_key_rotation" {
  type        = bool
  description = "Enable key rotation"
}

variable "kms_key_alias" {
  type        = string
  description = "Required alias for the KMS key"
}

variable "kms_admin_account_id" {
  type        = string
  description = "The admin account to manage the key"
}

variable "kms_account_region" {
  type        = string
  description = "The region to use for the KMS key"
}
