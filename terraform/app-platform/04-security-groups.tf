/*
 * Script Name: 04-main-security.tf
 * Project Name: Primus
 * Description: Defines the security group configuration for the EKS cluster.
 * This includes the Control Plane and Worker Node security groups,
 * enforcing a strict "mesh" of trust between the layers.
 *
 * ------------------------
 * Architectural Decisions:
 * ------------------------
 * - Least Privilege: Ingress rules are scoped strictly to source Security Groups
 * rather than broad CIDR blocks.
 * - Circular Dependency: Cross-referencing rules (Cluster <-> Node) are defined as
 * standalone resources to prevent Terraform dependency cycles.
 * - Control Plane Access: Public access to the API server is restricted at the network
 * layer (Security Group) to only allow traffic from Worker Nodes.
 * (Note: External kubectl access uses the public endpoint, not this SG).
 */

/*
* ----------------------
* CLUSTER SECURITY GROUP
* ----------------------
* Purpose:
*   Protects the EKS Control Plane (API Server).
*
* Rules & Rationale:
 *   - Ingress (HTTPS/443): Allowed from Worker Nodes (via standalone rule) to enable nodes to register
 *   with the cluster and report status updates.
 *   - Egress (HTTPS/443): Allowed to 0.0.0.0/0 to enable the Control Plane to communicate with
 *   AWS APIs (EC2, ECR, CloudWatch) via the VPC NAT Gateway or Internet Gateway.
 *   - Egress (Specific): Allowed to Worker Nodes (via standalone rules) for Kubelet and Webhook communication.
*/

module "eks_cluster_sg" {
  source = "../modules/security-groups"

  sg_name        = local.EKS_CLUSTER_SG_NAME
  sg_description = local.EKS_CLUSTER_SG_DESC
  sg_vpc_id      = module.main_vpc.vpc_id

  # Ingress rules defined externally to avoid circular dependency
  # Note: To allow management access (kubectl) from a peered DevOps VPC,
  # add an ingress rule allowing HTTPS (443) from the DevOps VPC CIDR
  # or a specific Bastion Security Group ID.
  sg_ingress_rules = {}

  # Security Optimization: Currently allows all outbound traffic (0.0.0.0/0) to reach AWS APIs.
  # To lock this down, restrict egress to specific VPC Endpoints (Interface/Gateway)
  # for services like EC2, ECR, CloudWatch, and STS.
  sg_egress_rules = {
    https_egress = {
      description              = "Allow HTTPS outbound traffic to Internet"
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      cidr_blocks              = ["0.0.0.0/0"]
      source_security_group_id = null
      self                     = null
    }
  }
}

/*
* -------------------
* NODE SECURITY GROUP
* -------------------
* Purpose:
*   Protects the EC2 Worker Nodes.
*
* Rules & Rationale:
 *   - Ingress (Self): Allows all traffic between nodes. Required for Pod-to-Pod communication
 *   across nodes and for the VPC CNI plugin to manage networking.
 *   - Ingress (Kubelet): TCP 10250 from Control Plane. Required for `kubectl logs`, `kubectl exec`,
 *   and metric scraping by the control plane.
 *   - Ingress (HTTPS): TCP 443 from Control Plane. Required for the API server to reach
 *   Admission Controllers (Webhooks) or Metrics Server running on nodes.
 *   - Egress (All): Allowed to 0.0.0.0/0. Required for nodes to pull container images (ECR/Docker Hub),
 *   perform OS updates, and reach AWS APIs (S3, DynamoDB, etc.).
*/

module "eks_node_sg" {
  source = "../modules/security-groups"

  sg_name        = local.EKS_NODE_SG_NAME
  sg_description = local.EKS_NODE_SG_DESC
  sg_vpc_id      = module.main_vpc.vpc_id

  sg_ingress_rules = {
    self_ingress = {
      description              = "Allow all internal traffic between nodes"
      from_port                = 0
      to_port                  = 0
      protocol                 = "-1"
      cidr_blocks              = null
      source_security_group_id = null
      self                     = true
    }
    cluster_kubelet = {
      description              = "Kubelet traffic from Control Plane"
      from_port                = 10250
      to_port                  = 10250
      protocol                 = "tcp"
      cidr_blocks              = null
      source_security_group_id = module.eks_cluster_sg.sg_id
      self                     = null
    }
    cluster_https = {
      description              = "HTTPS traffic from Control Plane (Webhooks)"
      from_port                = 443
      to_port                  = 443
      protocol                 = "tcp"
      cidr_blocks              = null
      source_security_group_id = module.eks_cluster_sg.sg_id
      self                     = null
    }
    cluster_webhook = {
      description              = "Webhook traffic from Control Plane"
      from_port                = 9443
      to_port                  = 9443
      protocol                 = "tcp"
      cidr_blocks              = null
      source_security_group_id = module.eks_cluster_sg.sg_id
      self                     = null
    }
    grafana_web = {
      description              = "Grafana UI from Internet"
      from_port                = 3000
      to_port                  = 3000
      protocol                 = "tcp"
      cidr_blocks              = ["0.0.0.0/0"]
      source_security_group_id = null
      self                     = null
    }
  }

  # Security Optimization: Currently allows all outbound traffic (0.0.0.0/0) for image pulling and OS updates.
  # To lock this down, restrict egress to specific destinations (e.g., S3 Gateway Endpoint, ECR Interface Endpoint)
  # and use a proxy for internet access if required.
  sg_egress_rules = {
    all_egress = {
      description              = "Allow all outbound traffic"
      from_port                = 0
      to_port                  = 0
      protocol                 = "-1"
      cidr_blocks              = ["0.0.0.0/0"]
      source_security_group_id = null
      self                     = null
    }
  }
}

/*
 * -------------------------------------------------------
 * CLUSTER <-> NODE RULES (AVOIDING CIRCULAR DEPENDENCIES)
 * -------------------------------------------------------
 * Purpose:
 *   Explicitly allow communication between the Control Plane and Worker Nodes.
 *   These are defined as standalone resources to resolve the "chicken-and-egg" dependency
 *   where the Cluster SG needs the Node SG ID, and the Node SG needs the Cluster SG ID.
 */

# 1. Cluster SG Ingress: Allow HTTPS from Nodes
resource "aws_security_group_rule" "cluster_https_from_node" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks_cluster_sg.sg_id
  source_security_group_id = module.eks_node_sg.sg_id
  # Rationale: Worker nodes must connect to the API Server (Control Plane) to register themselves,
  #            update their status (Heartbeats), and watch for new Pod assignments.
  description = "HTTPS from Worker Nodes"
}

# 2. Cluster SG Egress: Allow Kubelet traffic to Nodes
resource "aws_security_group_rule" "cluster_kubelet_to_node" {
  type                     = "egress"
  from_port                = 10250
  to_port                  = 10250
  protocol                 = "tcp"
  security_group_id        = module.eks_cluster_sg.sg_id
  source_security_group_id = module.eks_node_sg.sg_id
  # Rationale: The Control Plane initiates connections to the Kubelet (running on port 10250)
  #            on worker nodes to fetch logs, execute commands, and scrape metrics.
  description = "Kubelet traffic to Worker Nodes"
}

# 3. Cluster SG Egress: Allow HTTPS traffic to Nodes (Webhooks/Metrics)
resource "aws_security_group_rule" "cluster_https_to_node" {
  type                     = "egress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = module.eks_cluster_sg.sg_id
  source_security_group_id = module.eks_node_sg.sg_id
  # Rationale: The Control Plane initiates connections to Admission Controllers (Validating/Mutating Webhooks)
  #            and the Metrics Server running as Pods on the worker nodes, typically over HTTPS (443).
  description = "HTTPS traffic to Worker Nodes (Webhooks)"
}
