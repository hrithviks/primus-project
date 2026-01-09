/*
 * Script Name: locals.tf
 * Project Name: Primus
 * Description: Centralizes local value definitions and constants.
 * This file acts as a single source of truth for resource naming conventions,
 * IAM role identifiers, and service-specific configurations to ensure
 * consistency across the infrastructure.
 */

locals {
  RESOURCE_PREFIX = "${var.main_project_prefix}-${var.main_eks_env}"

  # Resource Names
  VPC_FLOW_LOG_NAME = "${local.RESOURCE_PREFIX}-vpc-flow-logs"

  # Resource Descriptions
  VPC_FLOW_LOG_DESC      = "CMK for encrypting EKS VPC Flow Logs"
  VPC_FLOW_LOG_KMS_ALIAS = "alias/${local.RESOURCE_PREFIX}-vpc-log-enc"

  # VPC Configuration
  VPC_DESC = "VPC for EKS Cluster ${local.RESOURCE_PREFIX}"

  # IAM Roles & Policies
  EKS_CLUSTER_ROLE_NAME      = "${local.RESOURCE_PREFIX}-eks-cluster-role"
  EKS_CLUSTER_ROLE_DESC      = "IAM Role for EKS Cluster Control Plane"
  EKS_CLUSTER_POLICY_NAME    = "${local.RESOURCE_PREFIX}-eks-cluster-custom-policy"
  EKS_CLUSTER_POLICY_DESC    = "Custom IAM Policy for EKS Cluster Control Plane (KMS)"
  EKS_BOUNDARY_NAME          = "${local.RESOURCE_PREFIX}-eks-cluster-boundary"
  EKS_BOUNDARY_DESC          = "Permissions boundary for EKS Cluster Role"
  EKS_NODE_ROLE_NAME         = "${local.RESOURCE_PREFIX}-eks-node-group-role"
  EKS_NODE_ROLE_DESC         = "IAM Role for EKS Worker Nodes"
  EBS_CSI_ROLE_NAME          = "${local.RESOURCE_PREFIX}-ebs-csi-driver-role"
  EBS_CSI_ROLE_DESC          = "IAM Role for EBS CSI Driver Add-on"
  ALB_CONTROLLER_ROLE_NAME   = "${local.RESOURCE_PREFIX}-alb-controller-role"
  ALB_CONTROLLER_ROLE_DESC   = "IAM Role for AWS Load Balancer Controller"
  ALB_CONTROLLER_POLICY_NAME = "${local.RESOURCE_PREFIX}-alb-controller-policy"
  ALB_CONTROLLER_POLICY_DESC = "IAM Policy for AWS Load Balancer Controller"
  AUTOSCALER_ROLE_NAME       = "${local.RESOURCE_PREFIX}-cluster-autoscaler-role"
  AUTOSCALER_ROLE_DESC       = "IAM Role for Cluster Autoscaler"
  AUTOSCALER_POLICY_NAME     = "${local.RESOURCE_PREFIX}-cluster-autoscaler-policy"
  AUTOSCALER_POLICY_DESC     = "IAM Policy for Cluster Autoscaler"
  CW_AGENT_ROLE_NAME         = "${local.RESOURCE_PREFIX}-cloudwatch-agent-role"
  CW_AGENT_ROLE_DESC         = "IAM Role for CloudWatch Agent (Metrics)"
  FLUENT_BIT_ROLE_NAME       = "${local.RESOURCE_PREFIX}-fluent-bit-role"
  FLUENT_BIT_ROLE_DESC       = "IAM Role for Fluent Bit (Logs)"
  ADMIN_ROLE_NAME            = "${local.RESOURCE_PREFIX}-admin-role"
  ADMIN_ROLE_DESC            = "IAM Role for Admin Namespace Access"
  ADMIN_GROUP_NAME           = "${local.RESOURCE_PREFIX}-admin-group"
  ADMIN_POLICY_NAME          = "${local.RESOURCE_PREFIX}-assume-admin-role-policy"
  ADMIN_POLICY_DESC          = "Allows assuming the Admin Namespace Role"

  # EKS Core Infrastructure
  EKS_CLUSTER_NAME         = "${local.RESOURCE_PREFIX}-cluster"
  EKS_CLUSTER_KMS_DESC     = "KMS key for EKS Cluster ${local.RESOURCE_PREFIX}"
  EKS_CLUSTER_KMS_ALIAS    = "alias/${local.RESOURCE_PREFIX}-eks-cluster"
  EKS_CLUSTER_LOG_GROUP    = "/aws/eks/${local.EKS_CLUSTER_NAME}/cluster"
  EKS_NODE_KEY_NAME        = "${local.RESOURCE_PREFIX}-eks-node-key"
  EKS_ADMIN_BUCKET_NAME    = "${local.RESOURCE_PREFIX}-eks-admin-assets"
  EKS_NODE_GROUP_NAME      = "${local.RESOURCE_PREFIX}-eks-node-group"
  EKS_LAUNCH_TEMPLATE_PFX  = "${local.RESOURCE_PREFIX}-eks-node-lt-"
  EKS_LAUNCH_TEMPLATE_DESC = "Launch template for EKS nodes"
  EKS_CLUSTER_SG_NAME      = "${local.RESOURCE_PREFIX}-eks-cluster-sg"
  EKS_CLUSTER_SG_DESC      = "Security Group for EKS Cluster Control Plane"
  EKS_NODE_SG_NAME         = "${local.RESOURCE_PREFIX}-eks-node-sg"
  EKS_NODE_SG_DESC         = "Security Group for EKS Worker Nodes"
  K8S_ADMIN_NAMESPACE      = "${local.RESOURCE_PREFIX}-admin"
  K8S_ADMIN_BINDING_NAME   = "${local.RESOURCE_PREFIX}-admin-group-binding"
}
