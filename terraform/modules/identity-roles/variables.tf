/*
 * Script Name  : variables.tf
 * Project Name : Primus
 * Description  : Defines the input variables required for the IAM Role module.
 *                These inputs establish the role's identity, trust relationships, and security constraints.
 * Scope        : Module (IAM Role)
 *
 * Variable Categories:
 * - Identity           : Name and description.
 * - Security           : Trust policy (assume role) and permissions boundary.
 * - Metadata           : Tags.
 */

variable "iam_role_name" {
  description = "The friendly name of the IAM role."
  type        = string
}

variable "iam_role_trust_policy" {
  description = "The JSON policy document that grants an entity permission (Trust policy) to assume the role."
  type        = string

  validation {
    condition     = can(jsondecode(var.iam_role_trust_policy))
    error_message = "The assume role policy must be a valid JSON string."
  }
}

variable "iam_role_description" {
  description = "The description of the IAM role."
  type        = string
  default     = null
}

variable "iam_role_tags" {
  description = "A map of tags to assign to the role."
  type        = map(string)
  default     = {}
}

variable "iam_role_permissions_boundary" {
  description = "The ARN of the policy used to set the permissions boundary for the role."
  type        = string
  default     = null

  # Either a null or a valid ARN
  validation {
    condition     = var.iam_role_permissions_boundary == null || can(regex("^arn:aws:iam::(\\d{12}|aws):policy/.+", var.iam_role_permissions_boundary))
    error_message = "Value must be valid IAM Policy ARNs (e.g., arn:aws:iam::aws:policy/Name or arn:aws:iam::123456789012:policy/Name)."
  }
}

variable "iam_role_policies" {
  description = "A list of IAM Policy ARNs (AWS managed or customer managed) to attach to the role."
  type        = list(string)
  default     = []

  # Either a null or a valid list of ARNs
  validation {
    condition     = var.iam_role_policies == null || alltrue([for arn in var.iam_role_policies : can(regex("^arn:aws:iam::(\\d{12}|aws):policy/.+", arn))])
    error_message = "All values must be valid IAM Policy ARNs (e.g., arn:aws:iam::aws:policy/Name or arn:aws:iam::123456789012:policy/Name)."
  }
}
