/*
 * Script Name  : variables.tf
 * Project Name : Primus
 * Description  : Input variables for the VPC Flow Logs Module
 * Scope        : Module (VPC Flow Logs)
 */

variable "vpc_flow_log_group_name" {
  type        = string
  description = "The name of the VPC Flow Log Group"
}

variable "vpc_flow_log_prefix" {
  type        = string
  description = "The prefix for the resources orchestrated by this module"
}

variable "vpc_flow_log_deletion_window" {
  type        = number
  description = "The deletion window in days"
  default     = 10
}

variable "vpc_flow_log_enable_key_rotation" {
  type        = bool
  description = "Enable key rotation"
  default     = true
}

variable "vpc_flow_log_retention_in_days" {
  type        = number
  description = "The retention period in days"
}

variable "vpc_flow_log_kms_alias" {
  type        = string
  description = "The alias for the CMK for encrypting VPC Flow Logs"
}

variable "vpc_flow_log_kms_description" {
  type        = string
  description = "The description for the CMK for encrypting VPC Flow Logs"
}
