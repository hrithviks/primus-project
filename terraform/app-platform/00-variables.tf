/*
 * Script Name: variables.tf
 * Project Name: Primus
 * Description: Defines the input variables required to configure the EKS cluster infrastructure.
 * These variables allow for dynamic parameterization of the environment, networking,
 * and tagging strategies.
 *
 * Variable Categories:
 * - Main Configuration: Global settings such as AWS region, project prefix, and environment name.
 * - Networking: CIDR blocks and Availability Zones for VPC and subnet construction.
 *
 * Validation Rules:
 * - Region Locking: Deployment is restricted to `ap-southeast-1` to ensure data sovereignty.
 * - CIDR Validation: Ensures that provided network ranges are valid IPv4 CIDR blocks.
 * - AZ Constraints: Enforces the use of specific Availability Zones for high availability.
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

variable "main_ssh_public_key" {
  description = "Public SSH key for EKS worker nodes. If provided, an EC2 Key Pair will be created."
  type        = string
  default     = null
}

/*
 * EKS section variables
 */

variable "eks_cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.34"
}

variable "eks_cluster_log_types" {
  description = "A list of the desired control plane logging to enable."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "eks_node_instance_types" {
  description = "List of instance types associated with the EKS Node Group."
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_node_desired_size" {
  description = "Desired number of worker nodes."
  type        = number
  default     = 3
}

variable "eks_node_max_size" {
  description = "Maximum number of worker nodes."
  type        = number
  default     = 5
}

variable "eks_node_min_size" {
  description = "Minimum number of worker nodes."
  type        = number
  default     = 2
}

variable "eks_node_max_unavailable" {
  description = "Maximum number of nodes unavailable during a rolling update."
  type        = number
  default     = 1
}

variable "eks_node_disk_size" {
  description = "Disk size in GB for worker nodes."
  type        = number
  default     = 30
}

variable "eks_node_disk_type" {
  description = "Disk type for worker nodes (e.g., gp3)."
  type        = string
  default     = "gp3"
}

/*
 * Observability Integration
 */
variable "logstash_host" {
  description = "The hostname of the Logstash server (ALB DNS) for log ingestion."
  type        = string
}
