/*
 * Script Name: config.tf
 * Project Name: Primus
 * Description: Defines the core Terraform configuration and provider requirements for the EKS cluster.
 * This file establishes the foundation for the infrastructure-as-code
 * execution environment, ensuring compatibility and consistent provider behavior.
 *
 * Configuration Details:
 * - Terraform Version: Specifies the required Terraform binary version to prevent
 * compatibility issues with state files and syntax.
 * - AWS Provider: Configures the AWS provider with the target region and
 * default tags for resource tracking and cost allocation.
 * - Kubernetes Provider: Configures the Kubernetes provider to interact with the EKS cluster
 * endpoint using AWS CLI authentication.
 *
 * Usage Guidelines:
 * - Version Pinning: It is recommended to pin provider versions to specific minor
 * releases to avoid breaking changes from automatic updates.
 * - Region Selection: The AWS region is dynamically set via the `main_aws_region` variable.
 */

terraform {
  required_version = ">= 1.14.0"

  # Configuration for required providers (AWS)
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.25"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1.0"
    }
  }
}

provider "aws" {
  region = var.main_aws_region

  default_tags {
    tags = var.main_default_tags
  }
}

/*
 * -------------------
 * KUBERNETES PROVIDER
 * -------------------
 * Configures the Kubernetes provider to interact with the EKS cluster.
 *
 * Dependency Note:
 * This provider configuration depends on the `aws_eks_cluster.main` resource.
 * Terraform will defer the initialization of this provider until the EKS cluster
 * details (endpoint, CA certificate) are available.
 *
 * Authentication Strategy:
 * Uses the `exec` plugin to dynamically retrieve an authentication token using the AWS CLI.
 * This is the recommended approach for EKS to handle token expiration automatically.
 */
provider "kubernetes" {
  # The API server endpoint retrieved from the EKS cluster resource.
  host = aws_eks_cluster.main.endpoint

  # The base64-encoded certificate authority data required to verify the API server's identity.
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

  # Dynamic authentication configuration using AWS CLI.
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
    command     = "aws"
  }
}

/*
 * -------------
 * HELM PROVIDER
 * -------------
 * Purpose:
 *   Configures the Helm provider to deploy charts into the EKS cluster.
 *   Uses the same dynamic authentication mechanism as the Kubernetes provider.
 */

provider "helm" {
  kubernetes = {
    host                   = aws_eks_cluster.main.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
      command     = "aws"
    }
  }
}
