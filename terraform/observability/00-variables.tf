/*
 * Script Name: variables.tf
 * Project Name: Primus
 * Description: Defines input variables for the ECS infrastructure configuration.
 * This file serves as the interface for parameterizing the deployment,
 * enforcing type constraints and validation rules to ensure data integrity.
 *
 * Configuration Scope:
 * - Main: Global project settings (Region, Tags, Environment).
 * - Network: VPC CIDR blocks, Subnets, and Availability Zones.
 */

/*
* Main configuration variables
*/
variable "main_aws_region" {
  description = "The target AWS region for the ECS cluster deployment."
  type        = string

  validation {
    condition     = var.main_aws_region == "ap-southeast-1"
    error_message = "The AWS region must be 'ap-southeast-1'."
  }
}

variable "main_default_tags" {
  description = "A map of default tags to apply to all supported resources for governance and cost allocation."
  type        = map(any)
}

variable "main_project_prefix" {
  description = "The project identifier used as a prefix for resource naming."
  type        = string
}

variable "main_ecs_env" {
  description = "The deployment environment identifier (e.g., dev, staging, prod)."
  type        = string
}

/*
* Network module configuration variables
*/
variable "network_vpc_cidr" {
  description = "The IPv4 CIDR block allocated for the Virtual Private Cloud (VPC)."
  type        = string

  validation {
    condition     = can(cidrhost(var.network_vpc_cidr, 0))
    error_message = "The VPC CIDR block must be a valid IPv4 CIDR."
  }
}

variable "network_public_subnets_cidr" {
  description = "A list of IPv4 CIDR blocks designated for public subnets."
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.network_public_subnets_cidr : can(cidrhost(cidr, 0))])
    error_message = "All public subnet CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "network_private_subnets_cidr" {
  description = "A list of IPv4 CIDR blocks designated for private subnets."
  type        = list(string)

  validation {
    condition     = alltrue([for cidr in var.network_private_subnets_cidr : can(cidrhost(cidr, 0))])
    error_message = "All private subnet CIDRs must be valid IPv4 CIDR blocks."
  }
}

variable "network_availability_zones" {
  description = "A list of Availability Zones for subnet distribution to ensure high availability."
  type        = list(string)

  validation {
    condition     = alltrue([for az in var.network_availability_zones : contains(["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"], az)])
    error_message = "Availability zones must be 'ap-southeast-1a', 'ap-southeast-1b' or 'ap-southeast-1c'."
  }
}

/*
ECS Section
*/

variable "ecs_os_secret_enc_id" {
  type        = string
  description = "The ID for the key manager resource used to encrypt the admin secret"
}

variable "ecs_os_secret_name" {
  type        = string
  description = "The name of the secret containing the admin password for OpenSearch"
}
