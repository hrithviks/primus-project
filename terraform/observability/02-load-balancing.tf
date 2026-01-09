/*
 * Script Name: main-alb.tf
 * Project Name: Primus
 * Description: Provisions the Application Load Balancer (ALB) and associated routing resources.
 * This component serves as the single entry point for external traffic, handling
 * path-based routing and health checking for backend ECS services.
 *
 * -----------------
 * Design Rationale:
 * -----------------
 * - Centralized Ingress: A single ALB manages traffic for multiple microservices (Dashboards,
 * Logstash, OpenSearch), reducing cost and complexity compared to
 * individual load balancers.
 * - Layer 7 Routing: Enables content-based routing (e.g., /dashboards/*) to direct traffic
 * to specific target groups.
 * - Protocol Separation: OpenSearch API traffic is isolated on port 9200 to mimic standard
 * behavior. Logstash is isolated on port 9600 (Monitoring) and 8080 (Ingest).
 */

/*
 * --------------------------
 * ALB SERVICES CONFIGURATION
 * --------------------------
 * Purpose: Defines the routing configuration map for path-based services.
 */
locals {
  alb_services = {
    dashboards = {
      name_suffix   = "db"
      port          = 5601
      health_check  = "/dashboards/api/status"
      matcher       = "200"
      priority      = 200
      path_patterns = ["/dashboards", "/dashboards/*"]
    }
  }
}

/*
 * -------------------------
 * APPLICATION LOAD BALANCER
 * -------------------------
 * Purpose:
 *   Deploys the Application Load Balancer infrastructure.
 *
 * Implementation Details:
 *   - Placement: Public subnets to accept internet traffic.
 *   - Security: Protected by a specific Security Group allowing HTTP (80) and API (9200) ingress.
 */
module "app_load_balancer" {
  source = "../modules/app-load-balancer"

  alb_name               = "${local.RESOURCE_PREFIX}-alb"
  alb_security_group_ids = [module.alb_sg.sg_id]
  alb_subnet_ids         = module.main_vpc.public_subnet_ids
}

/*
 * ----------------------------------
 * TARGET GROUPS (PATH-BASED ROUTING)
 * ----------------------------------
 * Purpose:
 *   Logical grouping of tasks for specific services (Dashboards, Logstash).
 *
 * Implementation Details:
 *   - Type: IP mode (required for Fargate).
 *   - Health Checks: Service-specific paths ensure traffic is only routed to healthy containers.
 */
resource "aws_lb_target_group" "services" {
  for_each = local.alb_services

  name        = "${local.RESOURCE_PREFIX}-${each.value.name_suffix}-tg"
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = module.main_vpc.vpc_id
  target_type = "ip"

  health_check {
    path    = each.value.health_check
    matcher = each.value.matcher
  }
}

/*
 * -----------------------------------
 * LISTENER RULES (PATH-BASED ROUTING)
 * -----------------------------------
 * Purpose:
 *   Directs incoming traffic on the main listener to the correct Target Group based on URL path.
 */
resource "aws_lb_listener_rule" "services" {
  for_each = local.alb_services

  listener_arn = module.app_load_balancer.alb_listener_arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    path_pattern {
      values = each.value.path_patterns
    }
  }
}

/*
 * --------------------------------------
 * OPENSEARCH TARGET GROUP (PORT ROUTING)
 * --------------------------------------
 * Purpose:
 *   Dedicated target group for the OpenSearch API.
 *
 * Implementation Details:
 *   - Port: 9200 (Standard OpenSearch API port).
 *   - Path: Root path (/) health check.
 */
resource "aws_lb_target_group" "opensearch" {
  name        = "${local.RESOURCE_PREFIX}-opensearch-tg"
  port        = 9200
  protocol    = "HTTP"
  vpc_id      = module.main_vpc.vpc_id
  target_type = "ip"

  health_check {
    path    = "/"
    matcher = "200"
  }
}

/*
 * -----------------------------------
 * OPENSEARCH LISTENER (PORT ROUTING)
 * -----------------------------------
 * Purpose:
 *   Dedicated listener for OpenSearch API traffic.
 *
 * Design Rationale:
 *   - Protocol Separation: Running the API on a distinct port (9200) avoids path rewriting
 *   complexities and mimics standard OpenSearch behavior.
 */
resource "aws_lb_listener" "opensearch" {
  load_balancer_arn = module.app_load_balancer.alb_arn
  port              = "9200"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.opensearch.arn
  }
}

/*
 * ------------------------------------
 * LOGSTASH TARGET GROUP (PORT ROUTING)
 * ------------------------------------
 * Purpose:
 *   Dedicated target group for the Logstash API.
 *
 * Implementation Details:
 *   - Port: 9600 (Standard Logstash monitoring port).
 *   - Path: Root path (/) health check.
 */
resource "aws_lb_target_group" "logstash" {
  name        = "${local.RESOURCE_PREFIX}-logstash-tg"
  port        = 9600
  protocol    = "HTTP"
  vpc_id      = module.main_vpc.vpc_id
  target_type = "ip"

  health_check {
    path    = "/"
    matcher = "200-499"
  }
}

/*
 * ---------------------------------
 * LOGSTASH LISTENER (PORT ROUTING)
 * ---------------------------------
 */
resource "aws_lb_listener" "logstash" {
  load_balancer_arn = module.app_load_balancer.alb_arn
  port              = "9600"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.logstash.arn
  }
}

/*
 * -----------------------------------------
 * LOGSTASH INGEST TARGET GROUP (HTTP INPUT)
 * -----------------------------------------
 * Purpose:
 *   Target group for the Logstash HTTP input pipeline.
 *
 * Implementation Details:
 *   - Port: 8080 (Common port for HTTP ingestion).
 */
resource "aws_lb_target_group" "logstash_ingest" {
  name        = "${local.RESOURCE_PREFIX}-ls-ingest-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.main_vpc.vpc_id
  target_type = "ip"

  health_check {
    path    = "/"
    matcher = "200"
  }
}

/*
 * --------------------------------------
 * LOGSTASH INGEST LISTENER (HTTP INPUT)
 * --------------------------------------
 */
resource "aws_lb_listener" "logstash_ingest" {
  load_balancer_arn = module.app_load_balancer.alb_arn
  port              = "8080"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.logstash_ingest.arn
  }
}
