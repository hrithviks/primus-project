/*
 * Script Name  : config.tf
 * Project Name : Primus
 * Description  : Defines the core Terraform configuration and provider requirements.
 *                This file establishes the foundation for the infrastructure-as-code
 *                execution environment, ensuring compatibility and consistent provider behavior.
 *
 * Configuration Details:
 * - Terraform Version : Specifies the required Terraform binary version to prevent
 *                       compatibility issues with state files and syntax.
 * - AWS Provider      : Configures the AWS provider with the target region and
 *                       default tags for resource tracking and cost allocation.
 *
 * Usage Guidelines:
 * - Version Pinning   : It is recommended to pin provider versions to specific minor
 *                       releases to avoid breaking changes from automatic updates.
 * - Region Selection  : The AWS region is dynamically set via the `main_aws_region` variable.
 */

terraform {
  required_version = ">= 1.14.0"

  # Configuration for required providers (AWS)
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.25"
    }
  }
}

provider "aws" {
  region = var.main_aws_region

  default_tags {
    tags = var.main_default_tags
  }
}
