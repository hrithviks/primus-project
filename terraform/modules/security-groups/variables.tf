/*
 * Script Name  : variables.tf
 * Project Name : Primus
 * Description  : Defines input variables for the Terraform configuration.
 * Scope        : Module (Security Groups)
 */

variable "sg_name" {
  type        = string
  description = "The name of the security group"
}

variable "sg_description" {
  type        = string
  description = "The description of the security group"
}

variable "sg_vpc_id" {
  type        = string
  description = "The VPC ID to attach the security group to"
}

variable "sg_ingress_rules" {
  description = "Map of ingress rules to create"
  type = map(object({
    description              = string
    from_port                = number
    to_port                  = number
    protocol                 = string
    cidr_blocks              = optional(list(string))
    source_security_group_id = optional(string)
    self                     = optional(bool)
  }))
  default = {}
}

variable "sg_egress_rules" {
  description = "Map of egress rules to create"
  type = map(object({
    description              = string
    from_port                = number
    to_port                  = number
    protocol                 = string
    cidr_blocks              = optional(list(string))
    source_security_group_id = optional(string)
    self                     = optional(bool)
  }))
  default = {}
}
