/*
 * Script Name: main-ecs-security.tf
 * Project Name: Primus
 * Description: Centralized configuration for all Security Groups within the ECS architecture.
 * This file defines the virtual firewalls controlling inbound and outbound traffic
 * for the Load Balancer, ECS Tasks, and EFS Storage.
 *
 * ------------------------
 * Architectural Decisions:
 * ------------------------
 * - Defense in Depth: Security Groups are applied at every layer (ALB, Compute, Storage) to enforce
 * strict network isolation.
 * - Least Privilege: Ingress rules are scoped to specific source Security Groups or CIDR blocks
 * rather than allowing broad access (0.0.0.0/0), except for public web endpoints.
 * - Service Mesh: ECS Tasks allow self-referencing ingress to enable internal communication
 * between containers without exposing ports to the VPC.
 *
 * ---------------------------------
 * Potential Security Optimizations:
 * ---------------------------------
 * - Egress Filtering: Currently, ECS services have broad egress access (0.0.0.0/0) to facilitate
 * image pulling (ECR) and log delivery (CloudWatch) via NAT Gateway. To achieve maximum security,
 * this should be restricted to specific VPC Interface Endpoints (PrivateLink) for
 * AWS services (ECR, S3, Logs, Secrets Manager). This ensures traffic never traverses the public internet or NAT Gateway.
 */

/*
 * ----------------------------------
 * APPLICATION LOAD BALANCER (ALB) SG
 * ----------------------------------
 * Purpose:
 *   Controls traffic reaching the public-facing Load Balancer.
 *
 * Implementation Details:
 *   - Ingress: Allows HTTP (80) and OpenSearch API (9200) traffic from the internet.
 *   - Ingress: Allows Logstash API (9600) traffic from the internet.
 *   - Ingress: Allows Logstash HTTP Input (8080) traffic from the internet.
 *   - Egress: Restricted to specific ECS service security groups via standalone rules.
 *
 * Design Rationale:
 *   - Public Entry Point: The ALB is the only resource exposed to the public internet.
 */
module "alb_sg" {
  source = "../modules/security-groups"

  sg_name        = "${local.RESOURCE_PREFIX}-alb-sg"
  sg_description = "Security Group for ALB ${local.RESOURCE_PREFIX}"
  sg_vpc_id      = module.main_vpc.vpc_id

  sg_ingress_rules = {
    http = {
      description = "HTTP from world"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    opensearch = {
      description = "OpenSearch API"
      from_port   = 9200
      to_port     = 9200
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    logstash = {
      description = "Logstash API"
      from_port   = 9600
      to_port     = 9600
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
    logstash_http = {
      description = "Logstash HTTP Input"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

/*
 * --------------------------
 * EFS STORAGE SECURITY GROUP
 * --------------------------
 * Purpose:
 *   Protects the persistent storage layer.
 *
 * Implementation Details:
 *   - Ingress: Restricted to NFS traffic (port 2049) from the OpenSearch Security Group.
 *
 * Design Rationale:
 *   - Data Protection: Ensures that the file system is only accessible by resources within the network boundary.
 */
module "efs_sg" {
  source = "../modules/security-groups"

  sg_name        = local.EFS_SG_NAME
  sg_description = local.EFS_SG_DESC
  sg_vpc_id      = module.main_vpc.vpc_id
}


/*
 * -------------------------
 * OPENSEARCH SECURITY GROUP
 * -------------------------
 * Purpose:
 *   Firewall for the OpenSearch stateful set.
 *
 * Implementation Details:
 *   - Ingress: 9200 from ALB, Dashboards, and Logstash.
 *   - Ingress: Self-referencing for cluster node communication.
 *   - Egress: Unrestricted.
 *
 * Design Rationale:
 *   - Microsegmentation: Only allows traffic from authorized sources (ALB and dependent services).
 */
module "opensearch_sg" {
  source = "../modules/security-groups"

  sg_name        = local.ECS_OS_SG_NAME
  sg_description = local.ECS_OS_SG_DESC
  sg_vpc_id      = module.main_vpc.vpc_id

  sg_ingress_rules = {
    alb = {
      description              = "API from ALB"
      from_port                = 9200
      to_port                  = 9200
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.sg_id
    }
    dashboards = {
      description              = "From Dashboards"
      from_port                = 9200
      to_port                  = 9200
      protocol                 = "tcp"
      source_security_group_id = module.dashboards_sg.sg_id
    }
    logstash = {
      description              = "From Logstash"
      from_port                = 9200
      to_port                  = 9200
      protocol                 = "tcp"
      source_security_group_id = module.logstash_sg.sg_id
    }
    self = {
      description = "Cluster communication"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      self        = true
    }
  }
  sg_egress_rules = {
    all = {
      description = "Allow all egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

/*
 * -------------------------
 * DASHBOARDS SECURITY GROUP
 * -------------------------
 * Purpose: Firewall for OpenSearch Dashboards.
 */
module "dashboards_sg" {
  source = "../modules/security-groups"

  sg_name        = local.ECS_DB_SG_NAME
  sg_description = local.ECS_DB_SG_DESC
  sg_vpc_id      = module.main_vpc.vpc_id

  sg_ingress_rules = {
    alb = {
      description              = "HTTP from ALB"
      from_port                = 5601
      to_port                  = 5601
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.sg_id
    }
  }
  sg_egress_rules = {
    all = {
      description = "Allow all egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

/*
 * -----------------------
 * LOGSTASH SECURITY GROUP
 * -----------------------
 * Purpose: Firewall for Logstash.
 */
module "logstash_sg" {
  source = "../modules/security-groups"

  sg_name        = local.ECS_LS_SG_NAME
  sg_description = local.ECS_LS_SG_DESC
  sg_vpc_id      = module.main_vpc.vpc_id

  sg_ingress_rules = {
    alb = {
      description              = "Input from ALB"
      from_port                = 9600
      to_port                  = 9600
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.sg_id
    }
    alb_ingest = {
      description              = "Ingest from ALB"
      from_port                = 8080
      to_port                  = 8080
      protocol                 = "tcp"
      source_security_group_id = module.alb_sg.sg_id
    }
  }
  sg_egress_rules = {
    all = {
      description = "Allow all egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

/*
 * -------------------------------------------------
 * ALB EGRESS RULES (AVOIDING CIRCULAR DEPENDENCIES)
 * -------------------------------------------------
 * Purpose:
 *   Explicitly allow ALB to talk to backend services on specific ports.
 *   Defined as standalone rules to resolve the "chicken and egg" dependency
 *   between ALB SG and Service SGs.
 */

resource "aws_security_group_rule" "alb_to_opensearch" {
  type                     = "egress"
  from_port                = 9200
  to_port                  = 9200
  protocol                 = "tcp"
  security_group_id        = module.alb_sg.sg_id
  source_security_group_id = module.opensearch_sg.sg_id
  description              = "ALB to OpenSearch"
}

resource "aws_security_group_rule" "alb_to_dashboards" {
  type                     = "egress"
  from_port                = 5601
  to_port                  = 5601
  protocol                 = "tcp"
  security_group_id        = module.alb_sg.sg_id
  source_security_group_id = module.dashboards_sg.sg_id
  description              = "ALB to Dashboards"
}

resource "aws_security_group_rule" "alb_to_logstash" {
  type                     = "egress"
  from_port                = 9600
  to_port                  = 9600
  protocol                 = "tcp"
  security_group_id        = module.alb_sg.sg_id
  source_security_group_id = module.logstash_sg.sg_id
  description              = "ALB to Logstash"
}

resource "aws_security_group_rule" "alb_to_logstash_ingest" {
  type                     = "egress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = module.alb_sg.sg_id
  source_security_group_id = module.logstash_sg.sg_id
  description              = "ALB to Logstash Ingest"
}

/*
 * ------------------------------------------
 * EFS RULES (AVOIDING CIRCULAR DEPENDENCIES)
 * ------------------------------------------
 * Purpose:
 *   Securely link OpenSearch and EFS without creating a cycle in the Terraform graph.
 */

resource "aws_security_group_rule" "efs_inbound_from_opensearch" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = module.efs_sg.sg_id
  source_security_group_id = module.opensearch_sg.sg_id
  description              = "NFS from OpenSearch"
}

resource "aws_security_group_rule" "opensearch_outbound_to_efs" {
  type                     = "egress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  security_group_id        = module.opensearch_sg.sg_id
  source_security_group_id = module.efs_sg.sg_id
  description              = "NFS to EFS"
}
