/*
 * Script Name  : variables.tf
 * Project Name : Primus
 * Description  : Defines the input variables required for the IAM Policy module.
 *                These inputs determine the policy's content, metadata, and optional association.
 * Scope        : Module (IAM/Policy)
 *
 * Variable Categories:
 * - Policy Metadata    : Name and description of the policy.
 * - Policy Content     : The actual JSON permission document.
 * - Association        : Optional role name for immediate attachment.
 */

variable "iam_policy_name" {
  type        = string
  description = "The friendly name of the IAM policy."
}

variable "iam_policy_description" {
  type        = string
  description = "The description of the IAM policy."
}

variable "iam_policy_document" {
  type        = string
  description = "The JSON policy document defining the permissions."

  # Ensures the document is a valid JSON string
  validation {
    condition     = can(jsondecode(var.iam_policy_document))
    error_message = "The policy document must be a valid JSON string."
  }
}

variable "iam_policy_attachment_role_name" {
  type        = string
  description = "The name of the IAM role to attach the policy to. If null, no attachment is created."
  default     = null
}

variable "iam_policy_attachment_group_name" {
  type        = string
  description = "The name of the IAM group to attach the policy to. If null, no attachment is created."
  default     = null
}
