/*
 * Script Name  : config.tf
 * Project Name : Primus
 * Description  : Main and provider configuration for EKS platform
 * Scope        : Root
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
