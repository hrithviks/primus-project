/*
 * Script Name: 05-main-eks.tf
 * Project Name: Primus
 * Description: Provisions the EKS Control Plane and Managed Node Groups.
 * This file defines the core Kubernetes infrastructure, including the
 * control plane configuration, worker node specifications, and
 * compute resource templates.
 *
 * ------------------------
 * Architectural Decisions:
 * ------------------------
 * - Control Plane: Deployed with version 1.34.
 * - Network Access: Both private and public endpoints are enabled.
 * - Private: For secure Node-to-Control Plane communication.
 * - Public: For management access (kubectl).
 * - Encryption: Envelope encryption enabled for Kubernetes Secrets using KMS.
 * - Compute Strategy: EKS Managed Node Groups are used to offload OS patching and
 * upgrades to AWS, while retaining control via Launch Templates.
 * - Storage Security: Root volumes for nodes are encrypted via KMS.
 */

/*
 * -----------------
 * EKS CONTROL PLANE
 * -----------------
 * Purpose:
 *   The central control point for the Kubernetes cluster.
 *
 * Configuration:
 *   - Logging: All control plane logs (API, Audit, etc.) are sent to CloudWatch.
 *   - Encryption: Secrets are encrypted at rest using the cluster KMS key.
 *   - Networking: Placed in private subnets for security, with security groups
 *   restricting traffic.
 */

resource "aws_eks_cluster" "main" {
  name = local.EKS_CLUSTER_NAME
  # The IAM role that provides permissions for the Kubernetes control plane to make calls to AWS API operations on your behalf.
  role_arn = module.eks_cluster_role.iam_role_arn
  version  = var.eks_cluster_version

  vpc_config {
    # Indicates which subnets the Cross-Account ENIs for the control plane will be placed in.
    # AWS creates approx 1 ENI per subnet here to provide a fixed HA network path; these do NOT scale dynamically with load.

    subnet_ids = module.main_vpc.private_subnet_ids
    # Security groups applied to the cross-account ENIs that the control plane uses to communicate with the cluster.

    security_group_ids = [module.eks_cluster_sg.sg_id]
    # Enables private access to the API server from within the VPC (Node <-> Control Plane).

    endpoint_private_access = true
    # Enables public access to the API server for management (kubectl) from outside the VPC.

    endpoint_public_access = true
  }

  # Access Configuration:
  # Explicitly sets the authentication mode to support both API (Access Entries) and ConfigMap.
  # Disables 'bootstrap_cluster_creator_admin_permissions' to ensure that ONLY the access entries
  # defined in Terraform (see 'Cluster Access Management' below) are granted admin rights.
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = false
  }

  encryption_config {
    provider {
      key_arn = module.eks_cluster_kms.kms_key_arn
    }
    # Encrypts Kubernetes Secrets (etcd) using the specified KMS key (Envelope Encryption).
    resources = ["secrets"]
  }

  # Enables CloudWatch logging for specific control plane components.
  enabled_cluster_log_types = var.eks_cluster_log_types

  depends_on = [
    module.eks_cluster_role,
    aws_cloudwatch_log_group.eks_cluster,
    module.main_vpc
  ]
}

/*
 * ----------------------
 * EKS MANAGED NODE GROUP
 * ----------------------
 * Purpose:
 *   Provisions the worker nodes that run the Kubernetes workloads.
 *   Uses a Launch Template to define the EC2 configuration (AMI, Disk, Security).
 */

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = local.EKS_NODE_GROUP_NAME

  # IAM role for the worker nodes, allowing them to make calls to AWS APIs (e.g., ECR, CNI).
  node_role_arn = module.eks_node_group_role.iam_role_arn

  # Subnets defining the placement scope for the Auto Scaling Group.
  # - General Scaling: The ASG attempts to balance nodes across these Availability Zones.
  # - Pod Constraints: If a pending Pod requires a specific AZ (e.g., for an existing EBS volume),
  # the Cluster Autoscaler forces the ASG to provision the node in that specific subnet.
  subnet_ids = module.main_vpc.private_subnet_ids

  # Instance type for the worker nodes.
  instance_types = var.eks_node_instance_types

  # Use a Launch Template to customize the EC2 instances (e.g., disk encryption, security groups).
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  # Auto Scaling Group configuration.
  scaling_config {
    desired_size = var.eks_node_desired_size
    max_size     = var.eks_node_max_size
    min_size     = var.eks_node_min_size
  }

  # Configuration for node updates (rolling updates).
  update_config {
    # Max number of nodes unavailable during an update.
    max_unavailable = var.eks_node_max_unavailable
  }

  # Ignore changes to the desired size of the node group.
  # This prevents Terraform from reverting changes made by the Cluster Autoscaler or manual updates.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    module.eks_node_group_role,
    module.main_vpc
  ]

  tags = {
    Name = "${local.RESOURCE_PREFIX}-eks-node-group"
  }
}

/*
 * -------------------
 * EC2 LAUNCH TEMPLATE
 * -------------------
 * Purpose:
 *   Defines the configuration for the EC2 instances in the Node Group.
 *   Ensures that all nodes are launched with encrypted volumes, specific tags,
 *   and restricted metadata access.
 */

resource "aws_launch_template" "eks_nodes" {
  name_prefix            = local.EKS_LAUNCH_TEMPLATE_PFX
  description            = local.EKS_LAUNCH_TEMPLATE_DESC
  update_default_version = true

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.eks_node_disk_size
      volume_type           = var.eks_node_disk_type
      encrypted             = true
      delete_on_termination = true
      kms_key_id            = module.eks_cluster_kms.kms_key_arn
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [module.eks_node_sg.sg_id]
    delete_on_termination       = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      var.main_default_tags,
      {
        Name = "${local.RESOURCE_PREFIX}-eks-node"
        # Change this tag value to force a new Launch Template version and trigger node rotation
        ForceUpdate = "prefix-delegation"
      }
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      var.main_default_tags,
      {
        Name = "${local.RESOURCE_PREFIX}-eks-node-volume"
      }
    )
  }
}

/*
 * -------------------------
 * CLUSTER ACCESS MANAGEMENT
 * -------------------------
 * Purpose:
 *   Configures authentication and authorization for the EKS cluster using EKS Access Entries.
 *   This modern approach replaces the legacy `aws-auth` ConfigMap, allowing access management
 *   directly via AWS APIs.
 *
 * Configuration:
 *   - Admin Access: Automatically grants the Terraform execution role (current caller)
 *   full cluster administrative privileges (`AmazonEKSClusterAdminPolicy`).
 *   - Type: "STANDARD" is used for general IAM principals (Users/Roles).
 *   (Other types like EC2_LINUX are reserved for node registration).
 *   - Node Access: Managed Node Groups automatically create Access Entries (type EC2_LINUX)
 *   for their associated IAM roles; no explicit resource is required here.
 */
resource "aws_eks_access_entry" "main" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = data.aws_caller_identity.current.arn
  type          = "STANDARD"
}

# Associates the "Cluster Admin" access policy with the principal.
# Note: The AWS-managed 'AmazonEKSClusterAdminPolicy' is utilized because custom EKS Access Policies
# are not supported. This policy grants full 'cluster-admin' rights (all namespaces).
# For granular permissions (e.g., specific namespaces), the Access Entry should be mapped
# to a Kubernetes Group to leverage native K8s RBAC instead of this Policy Association.
resource "aws_eks_access_policy_association" "main" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.main.principal_arn

  # Kubernetes level scoping (e.g Namespace)
  access_scope {
    type = "cluster"
  }
}
