/*
 * Script Name  : main-logstash.tf
 * Project Name : Primus
 * Description  : Provisions the Logstash service on ECS.
 *                Logstash serves as the server-side data processing pipeline that ingests data
 *                from a multitude of sources, transforms it, and sends it to OpenSearch.
 *
 * -----------------
 * Design Rationale:
 * -----------------
 * - Data Ingestion Layer : Decouples data collection from storage (OpenSearch). This allows for
 *                          buffering, transformation, and enrichment of logs before indexing.
 * - Scalability          : Running as a stateless ECS service allows the ingestion layer to scale
 *                          independently based on incoming log volume.
 * - Pipeline Flexibility : Supports various input plugins (e.g., HTTP, Beats) and output plugins
 *                          configured via container definitions.
 */

/*
 * ------------------
 * IAM EXECUTION ROLE
 * ------------------
 * Purpose:
 *   Grants the ECS agent permission to make AWS API calls on your behalf.
 *
 * Implementation Details:
 *   - Permissions : Pulling images from ECR, writing logs to CloudWatch.
 *
 * Design Rationale:
 *   - Least Privilege : Separating execution permissions (infrastructure) from task permissions
 *                       (application) ensures the application cannot manipulate the infrastructure.
 */

module "ecs_logstash_exec_role" {
  source = "../modules/identity-roles"

  iam_role_name        = local.ECS_LS_EXEC_ROLE_NAME
  iam_role_description = local.ECS_LS_EXEC_ROLE_DESC

  iam_role_assume_role_policy = templatefile("./templates/iam-trust-policy.json", { SERVICE_NAME = "ecs-tasks.amazonaws.com" })
}

module "ecs_logstash_exec_role_policy" {
  source = "../modules/identity-policies"

  iam_policy_name        = local.ECS_LS_EXEC_POLICY_NAME
  iam_policy_description = local.ECS_LS_EXEC_POLICY_DESC

  iam_policy_document = templatefile("./templates/logstash/ecs-ls-execution-role.json", {
    RESOURCE_PREFIX = local.RESOURCE_PREFIX
    AWS_REGION      = local.AWS_REGION
    AWS_ACCOUNT_ID  = local.AWS_ACCOUNT_ID
  })

  iam_policy_attachment_role_name = module.ecs_logstash_exec_role.iam_role_name
}

/*
 * -------------
 * IAM TASK ROLE
 * -------------
 * Purpose:
 *   Grants the Logstash application permissions to interact with other AWS services defined in its pipeline.
 *
 * Design Rationale:
 *   - Security Boundary : Ensures the pipeline only has access to specific resources required for
 *                         data processing (e.g., S3 buckets, Kinesis streams).
 */

module "ecs_logstash_task_role" {
  source = "../modules/identity-roles"

  iam_role_name        = local.ECS_LS_TASK_ROLE_NAME
  iam_role_description = local.ECS_LS_TASK_ROLE_DESC

  iam_role_assume_role_policy = templatefile("./templates/iam-trust-policy.json", {
    SERVICE_NAME = "ecs-tasks.amazonaws.com"
  })
}

module "ecs_logstash_task_role_policy" {
  source = "../modules/identity-policies"

  iam_policy_name        = local.ECS_LS_TASK_POLICY_NAME
  iam_policy_description = local.ECS_LS_TASK_POLICY_DESC

  iam_policy_document = templatefile("./templates/logstash/ecs-ls-task-role.json", {
    RESOURCE_PREFIX = local.RESOURCE_PREFIX
    AWS_REGION      = local.AWS_REGION
    AWS_ACCOUNT_ID  = local.AWS_ACCOUNT_ID
  })

  iam_policy_attachment_role_name = module.ecs_logstash_task_role.iam_role_name
}

/*
 * --------------------
 * ECS TASK AND SERVICE
 * --------------------
 * Purpose:
 *   Defines the runtime configuration for the Logstash container.
 *
 * Implementation Details:
 *   - Compute       : Fargate (Serverless).
 *   - Networking    : Private subnet placement; accessible via ALB (HTTP input) or internal service discovery.
 *   - Configuration : Environment variables define the OpenSearch output destination.
 *
 * Design Rationale:
 *   - Stateless Processing : Logstash containers are ephemeral; pipeline state is managed externally
 *                            (e.g., in the source queue or destination), allowing easy replacement.
 */

module "logstash" {
  source = "../modules/ecs-service"

  ecs_task_family_name                  = "${local.RESOURCE_PREFIX}-logstash-task"
  ecs_name                              = local.ECS_LOGSTASH_NAME
  ecs_task_cpu                          = 512
  ecs_task_memory                       = 1024
  ecs_task_execution_role_arn           = module.ecs_logstash_exec_role.iam_role_arn
  ecs_task_role_arn                     = module.ecs_logstash_task_role.iam_role_arn
  ecs_cluster_id                        = aws_ecs_cluster.main.id
  ecs_subnet_ids                        = module.main_vpc.private_subnet_ids
  ecs_security_group_ids                = [module.logstash_sg.sg_id]
  ecs_service_registry_arn              = aws_service_discovery_service.main["logstash"].arn
  ecs_target_group_arn                  = aws_lb_target_group.services["logstash"].arn
  ecs_container_port                    = 9600
  ecs_health_check_grace_period_seconds = 60

  ecs_task_container_definitions = templatefile("templates/logstash/ecs-ls-container-defn.json", {
    NAME             = local.ECS_LOGSTASH_NAME
    IMAGE            = "opensearchproject/logstash-oss-with-opensearch-output-plugin:latest"
    OPENSEARCH_HOSTS = "http://${local.ECS_OPENSEARCH_NAME}.${local.CLOUDMAP_NAMESPACE_NAME}:9200"
    LOG_GROUP        = aws_cloudwatch_log_group.ecs_log_group.name
    REGION           = local.AWS_REGION
    STREAM_PREFIX    = local.ECS_LOGSTASH_NAME
  })
}
