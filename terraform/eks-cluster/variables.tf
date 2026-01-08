/*
 * Script Name  : variables.tf
 * Project Name : Primus
 * Description  : Defines input variables for the EKS configuration.
 * Scope        : Root
 */

/*
* Main configuration variables
*/
variable "main_aws_region" {
  description = "The AWS region to deploy the cluster into"
  type        = string

  validation {
    condition     = var.main_aws_region == "ap-southeast-1"
    error_message = "The AWS region must be 'ap-southeast-1'."
  }
}

variable "main_default_tags" {
  description = "The default tags for all the resources"
  type        = map(any)
}

variable "main_project_prefix" {
  description = "The project prefix for resources"
  type        = string
}

variable "main_eks_env" {
  description = "The environment for ECS cluster configuration"
  type        = string
}

/*
* Network module configuration variables
*/
variable "network_vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.network_vpc_cidr, 0))
    error_message = "The VPC CIDR block must be a valid IPv4 CIDR."
  }
}

variable "network_public_subnets_cidr" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.network_public_subnets_cidr : can(cidrhost(cidr, 0))])
    error_message = "All public subnet CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "network_private_subnets_cidr" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.network_private_subnets_cidr : can(cidrhost(cidr, 0))])
    error_message = "All private subnet CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "network_availability_zones" {
  description = "List of availability zones to distribute subnets across"
  type        = list(string)

  validation {
    condition     = alltrue([for az in var.network_availability_zones : contains(["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"], az)])
    error_message = "Availability zones must be 'ap-southeast-1a', 'ap-southeast-1b' or 'ap-southeast-1c'."
  }
}
