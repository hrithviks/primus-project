/*
 * Script Name: main-dashboard.tf
 * Project Name: Primus
 * Description: Provisions the OpenSearch Dashboards service on ECS.
 * This component provides the visualization layer for the observability stack,
 * allowing users to query and visualize data stored in OpenSearch.
 *
 * -----------------
 * Design Rationale:
 * -----------------
 * - Decoupled UI: Running Dashboards as a separate service allows independent scaling
 * and maintenance from the data nodes (OpenSearch).
 * - Statelessness: The Dashboards service is stateless, simplifying scaling and recovery.
 * Configuration is stored in the OpenSearch cluster itself.
 * - Path-Based Routing: Accessed via a specific path (/dashboards) on the shared ALB to
 * conserve public IP addresses and simplify DNS management.
 */

/*
 * ------------------
 * IAM EXECUTION ROLE
 * ------------------
 * Purpose:
 *   Grants the ECS agent permission to make AWS API calls on your behalf.
 *
 * Implementation Details:
 *   - Permissions: Pulling images from ECR, writing logs to CloudWatch.
 *
 * Design Rationale:
 *   - Least Privilege: Separating execution permissions (infrastructure) from task permissions
 *   (application) ensures the application cannot manipulate the infrastructure.
 */

module "ecs_dashboards_exec_role" {
  source = "../modules/identity-roles"

  iam_role_name        = local.ECS_DB_EXEC_ROLE_NAME
  iam_role_description = local.ECS_DB_EXEC_ROLE_DESC

  iam_role_trust_policy = templatefile("./templates/iam-trust-policy.json", { SERVICE_NAME = "ecs-tasks.amazonaws.com" })
}

module "ecs_dashboards_exec_role_policy" {
  source = "../modules/identity-policies"

  iam_policy_name        = local.ECS_DB_EXEC_POLICY_NAME
  iam_policy_description = local.ECS_DB_EXEC_POLICY_DESC

  iam_policy_document = templatefile("./templates/dashboards/ecs-db-execution-role.json", {
    RESOURCE_PREFIX = local.RESOURCE_PREFIX
    AWS_REGION      = local.AWS_REGION
    AWS_ACCOUNT_ID  = local.AWS_ACCOUNT_ID
  })

  iam_policy_attachment_role_name = module.ecs_dashboards_exec_role.iam_role_name
}

/*
 * -------------
 * IAM TASK ROLE
 * -------------
 * Purpose:
 *   Grants the actual application container permissions to call other AWS services.
 *
 * Design Rationale:
 *   - Security Boundary: Ensures the container only has access to resources it explicitly needs.
 */

module "ecs_dashboards_task_role" {
  source = "../modules/identity-roles"

  iam_role_name        = local.ECS_DB_TASK_ROLE_NAME
  iam_role_description = local.ECS_DB_TASK_ROLE_DESC

  iam_role_trust_policy = templatefile("./templates/iam-trust-policy.json", {
    SERVICE_NAME = "ecs-tasks.amazonaws.com"
  })
}

module "ecs_dashboards_task_role_policy" {
  source = "../modules/identity-policies"

  iam_policy_name        = local.ECS_DB_TASK_POLICY_NAME
  iam_policy_description = local.ECS_DB_TASK_POLICY_DESC

  iam_policy_document = templatefile("./templates/dashboards/ecs-db-task-role.json", {
    RESOURCE_PREFIX = local.RESOURCE_PREFIX
    AWS_REGION      = local.AWS_REGION
    AWS_ACCOUNT_ID  = local.AWS_ACCOUNT_ID
  })

  iam_policy_attachment_role_name = module.ecs_dashboards_task_role.iam_role_name
}

/*
 * --------------------
 * ECS TASK AND SERVICE
 * --------------------
 * Purpose:
 *   Defines the runtime configuration for the OpenSearch Dashboards container.
 *
 * Implementation Details:
 *   - Compute: Fargate (Serverless).
 *   - Networking: Private subnet placement; accessible only via ALB.
 *   - Configuration: Environment variables configure the connection to the OpenSearch cluster
 *   and handle base path rewriting for ALB routing.
 *
 * Design Rationale:
 *   - Base Path Rewriting: Since the service sits behind an ALB path (/dashboards), the application
 *   must be aware of this prefix to generate correct internal links and assets.
 */

/*
 * -----------------------------------
 * SERVICE PRODUCTION READINESS REVIEW
 * -----------------------------------
 * The current implementation represents a functional configuration suitable for
 * development or proof-of-concept environments. For a production-grade deployment,
 * the following architectural gaps must be addressed to ensure security, stability, and scale:
 *
 * 1. Security & Access Control:
 * - Public Exposure: The service is exposed via a public ALB. While Security Groups restrict
 * ports, the application login page is accessible to the internet. Production setups should
 * place this behind a VPN or use AWS ALB Authentication (OIDC/Cognito) to pre-authenticate
 * users before traffic reaches the container.
 * - Transport Encryption: Traffic from ALB to Container is HTTP. End-to-end encryption (HTTPS)
 * should be enforced to protect session cookies and credentials.
 *
 * 2. High Availability:
 * - Session Management: If scaled beyond one replica, Dashboards requires sticky sessions (ALB)
 * or a shared session store (OpenSearch indices) to prevent users from being logged out
 * during requests.
 *
 * 3. Configuration Management:
 * - Hardcoded Config: Configuration is baked into the container or passed via ENV vars.
 * Complex setups (multi-tenancy, reporting) require mounting a custom `opensearch_dashboards.yml`
 * via EFS or S3 to manage advanced settings without rebuilding images.
 *
 * 4. Cold Starts:
 * - Startup Latency: Fargate tasks take time to launch. If the service scales aggressively,
 * users may experience delays. Mitigation includes scheduled scaling actions to
 * pre-warm the service before peak usage hours.
 */
module "dashboards" {
  source = "../modules/ecs-service"

  ecs_task_family_name                  = "${local.RESOURCE_PREFIX}-dashboards-task"
  ecs_name                              = local.ECS_DASHBOARDS_NAME
  ecs_task_cpu                          = 512
  ecs_task_memory                       = 1024
  ecs_task_execution_role_arn           = module.ecs_dashboards_exec_role.iam_role_arn
  ecs_task_role_arn                     = module.ecs_dashboards_task_role.iam_role_arn
  ecs_cluster_id                        = aws_ecs_cluster.main.id
  ecs_subnet_ids                        = module.main_vpc.private_subnet_ids
  ecs_security_group_ids                = [module.dashboards_sg.sg_id]
  ecs_service_registry_arn              = aws_service_discovery_service.main["dashboards"].arn
  ecs_target_group_arn                  = aws_lb_target_group.services["dashboards"].arn
  ecs_container_port                    = 5601
  ecs_health_check_grace_period_seconds = 60

  ecs_task_container_definitions = templatefile("templates/dashboards/ecs-db-container-defn.json", {
    NAME                   = local.ECS_DASHBOARDS_NAME
    IMAGE                  = "opensearchproject/opensearch-dashboards:latest"
    OPENSEARCH_HOSTS       = "http://${local.ECS_OPENSEARCH_NAME}.${local.CLOUDMAP_NAMESPACE_NAME}:9200"
    LOG_GROUP              = aws_cloudwatch_log_group.ecs_log_group.name
    REGION                 = local.AWS_REGION
    STREAM_PREFIX          = local.ECS_DASHBOARDS_NAME
    SERVER_BASEPATH        = "/dashboards"
    SERVER_REWRITEBASEPATH = "true"
  })
}
