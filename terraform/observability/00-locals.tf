/*
 * Script Name: locals.tf
 * Project Name: Primus
 * Description: Centralizes local value definitions and constants.
 * This file acts as a single source of truth for resource naming conventions,
 * IAM role identifiers, and service-specific configurations to ensure
 * consistency across the infrastructure.
 */

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {

  # Data source resources
  AWS_ACCOUNT_ID = data.aws_caller_identity.current.account_id
  AWS_REGION     = data.aws_region.current.id

  # Prefix for all resources
  RESOURCE_PREFIX = "${var.main_project_prefix}-${var.main_ecs_env}"

  # VPC Section
  VPC_FLOW_LOG_NAME = "${local.RESOURCE_PREFIX}-vpc-flow-logs"

  # IAM Names - OpenSearch
  ECS_OS_EXEC_ROLE_NAME   = "${local.RESOURCE_PREFIX}-opensearch-execution-role"
  ECS_OS_EXEC_POLICY_NAME = "${local.RESOURCE_PREFIX}-opensearch-execution-policy"
  ECS_OS_TASK_ROLE_NAME   = "${local.RESOURCE_PREFIX}-opensearch-task-role"
  ECS_OS_TASK_POLICY_NAME = "${local.RESOURCE_PREFIX}-opensearch-task-policy"

  # IAM Names - Dashboards
  ECS_DB_EXEC_ROLE_NAME   = "${local.RESOURCE_PREFIX}-dashboards-execution-role"
  ECS_DB_EXEC_POLICY_NAME = "${local.RESOURCE_PREFIX}-dashboards-execution-policy"
  ECS_DB_TASK_ROLE_NAME   = "${local.RESOURCE_PREFIX}-dashboards-task-role"
  ECS_DB_TASK_POLICY_NAME = "${local.RESOURCE_PREFIX}-dashboards-task-policy"

  # IAM Names - Logstash
  ECS_LS_EXEC_ROLE_NAME   = "${local.RESOURCE_PREFIX}-logstash-execution-role"
  ECS_LS_EXEC_POLICY_NAME = "${local.RESOURCE_PREFIX}-logstash-execution-policy"
  ECS_LS_TASK_ROLE_NAME   = "${local.RESOURCE_PREFIX}-logstash-task-role"
  ECS_LS_TASK_POLICY_NAME = "${local.RESOURCE_PREFIX}-logstash-task-policy"

  # ECS Names
  ECS_OPENSEARCH_NAME = "opensearch"
  ECS_DASHBOARDS_NAME = "dashboards"
  ECS_LOGSTASH_NAME   = "logstash"
  ECS_SERVICES = {
    opensearch = local.ECS_OPENSEARCH_NAME
    dashboards = local.ECS_DASHBOARDS_NAME
    logstash   = local.ECS_LOGSTASH_NAME
  }

  KMS_STORAGE_ALIAS       = "alias/${local.RESOURCE_PREFIX}-storage-enc"
  ECS_LOG_GROUP_NAME      = "${local.RESOURCE_PREFIX}-ecs-log-group"
  EFS_NAME                = "${local.RESOURCE_PREFIX}-efs"
  EFS_SG_NAME             = "${local.RESOURCE_PREFIX}-efs-sg"
  CLOUDMAP_NAMESPACE_NAME = "${local.RESOURCE_PREFIX}.local"
  ECS_CLUSTER_NAME        = "${local.RESOURCE_PREFIX}-cluster"
  ECS_OS_SG_NAME          = "${local.RESOURCE_PREFIX}-opensearch-sg"
  ECS_DB_SG_NAME          = "${local.RESOURCE_PREFIX}-dashboards-sg"
  ECS_LS_SG_NAME          = "${local.RESOURCE_PREFIX}-logstash-sg"

  # Resource Descriptions
  VPC_FLOW_LOG_DESC       = "CMK for encrypting observability VPC Flow Logs"
  KMS_STORAGE_DESC        = "CMK for encrypting observability storage (CloudWatch, EFS) ${local.RESOURCE_PREFIX}"
  EFS_SG_DESC             = "Security group for EFS ${local.RESOURCE_PREFIX}"
  CLOUDMAP_NAMESPACE_DESC = "Service discovery namespace for ${local.RESOURCE_PREFIX}"
  ECS_CLUSTER_DESC        = "ECS Cluster for Observability ${local.RESOURCE_PREFIX}"
  ECS_OS_SG_DESC          = "Security Group for OpenSearch Service ${local.RESOURCE_PREFIX}"
  ECS_DB_SG_DESC          = "Security Group for Dashboards Service ${local.RESOURCE_PREFIX}"
  ECS_LS_SG_DESC          = "Security Group for Logstash Service ${local.RESOURCE_PREFIX}"

  ECS_OS_EXEC_ROLE_DESC   = "The IAM role for ECS Execution OpenSearch ${local.RESOURCE_PREFIX}"
  ECS_OS_EXEC_POLICY_DESC = "The IAM policy for ECS Execution OpenSearch ${local.RESOURCE_PREFIX}"
  ECS_OS_TASK_ROLE_DESC   = "The IAM role for ECS Task OpenSearch ${local.RESOURCE_PREFIX}"
  ECS_OS_TASK_POLICY_DESC = "Permissions for ECS OpenSearch tasks"

  ECS_DB_EXEC_ROLE_DESC   = "The IAM role for ECS Execution Dashboards ${local.RESOURCE_PREFIX}"
  ECS_DB_EXEC_POLICY_DESC = "The IAM policy for ECS Execution Dashboards ${local.RESOURCE_PREFIX}"
  ECS_DB_TASK_ROLE_DESC   = "The IAM role for ECS Task Dashboards ${local.RESOURCE_PREFIX}"
  ECS_DB_TASK_POLICY_DESC = "Permissions for ECS Dashboards tasks"

  ECS_LS_EXEC_ROLE_DESC   = "The IAM role for ECS Execution Logstash ${local.RESOURCE_PREFIX}"
  ECS_LS_EXEC_POLICY_DESC = "The IAM policy for ECS Execution Logstash ${local.RESOURCE_PREFIX}"
  ECS_LS_TASK_ROLE_DESC   = "The IAM role for ECS Task Logstash ${local.RESOURCE_PREFIX}"
  ECS_LS_TASK_POLICY_DESC = "Permissions for ECS Logstash tasks"
}
