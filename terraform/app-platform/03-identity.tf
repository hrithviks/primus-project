/*
 * Script Name: 02-main-iam.tf
 * Project Name: Primus
 * Description: Manages Identity and Access Management (IAM) resources for the EKS cluster.
 * This includes roles for the control plane, worker nodes, and add-ons,
 * enforcing least privilege and permission boundaries.
 *
 * ------------------------
 * Architectural Decisions:
 * ------------------------
 * - IRSA (IAM Roles for Service Accounts):
 * Used for add-ons (like EBS CSI) to grant granular permissions at the pod level instead of the node level.
 * - Permission Boundaries:
 * Applied to cluster roles to restrict the scope of resources that can be created (e.g., enforcing VPC isolation).
 * - OIDC Provider:
 * Configured to enable trust between the EKS cluster and AWS IAM.
 */

/*
 * --------------------
 * PERMISSIONS BOUNDARY
 * --------------------
 * Purpose:
 *   Defines the maximum permissions that the cluster and node roles can have.
 *   It enforces network isolation (VPC) and tagging standards.
 */

module "eks_cluster_boundary" {
  source = "../modules/identity-policies"

  iam_policy_name        = local.EKS_BOUNDARY_NAME
  iam_policy_description = local.EKS_BOUNDARY_DESC
  iam_policy_document = templatefile("./templates/iam-eks-cluster-boundary-policy.json", {
    VPC_ID = module.main_vpc.vpc_id
  })
}

/*
 * ----------------
 * EKS CLUSTER ROLE
 * ----------------
 * Purpose:
 *   Allows the EKS control plane to manage AWS resources (like Load Balancers, ENIs) on your behalf.
 *
 * Security Controls:
 *   - Trust Policy: Trusted entity is `eks.amazonaws.com`.
 *   - Permission Boundary: Leveraged to restrict the broad scope of the AWS Managed Policy.
 *   It limits resource creation to the specific VPC and enforces tagging,
 *   with the flexibility to expand constraints further as needed.
 */

module "eks_cluster_custom_policy" {
  source = "../modules/identity-policies"

  iam_policy_name        = local.EKS_CLUSTER_POLICY_NAME
  iam_policy_description = local.EKS_CLUSTER_POLICY_DESC
  iam_policy_document = templatefile("./templates/iam-eks-cluster-custom-policy.json", {
    KMS_KEY_ARN   = module.eks_cluster_kms.kms_key_arn
    LOG_GROUP_ARN = aws_cloudwatch_log_group.eks_cluster.arn
  })
  iam_policy_attachment_role_name = null
}

module "eks_cluster_role" {
  source = "../modules/identity-roles"

  iam_role_name                 = local.EKS_CLUSTER_ROLE_NAME
  iam_role_description          = local.EKS_CLUSTER_ROLE_DESC
  iam_role_trust_policy         = templatefile("./templates/iam-trust-policy.json", { SERVICE_NAME = "eks.amazonaws.com" })
  iam_role_permissions_boundary = module.eks_cluster_boundary.iam_policy_arn
  iam_role_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    module.eks_cluster_custom_policy.iam_policy_arn
  ]
}

/*
 * -----------------------
 * EKS NODE GROUP IAM ROLE
 * -----------------------
 * Purpose:
 *   Allows EC2 instances (worker nodes) to register with the cluster and pull container images.
 *
 * Security Controls:
 *   - Trust Policy: Trusted entity is `ec2.amazonaws.com`.
 *   - Permission Boundary: Inherits the cluster boundary for consistency.
 */

module "eks_node_group_role" {
  source = "../modules/identity-roles"

  iam_role_name                 = local.EKS_NODE_ROLE_NAME
  iam_role_description          = local.EKS_NODE_ROLE_DESC
  iam_role_trust_policy         = templatefile("./templates/iam-trust-policy.json", { SERVICE_NAME = "ec2.amazonaws.com" })
  iam_role_permissions_boundary = module.eks_cluster_boundary.iam_policy_arn
  iam_role_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  ]
}

/*
 * -----------------
 * IAM OIDC PROVIDER
 * -----------------
 * Purpose:
 *   Establishes a trust relationship between the EKS cluster's OIDC issuer and AWS IAM.
 *   This is the foundation for IAM Roles for Service Accounts (IRSA).
 *
 * Note on Scope:
 *   The OIDC provider is cluster-wide, but permissions are NOT inherited by all namespaces.
 *   Access is strictly scoped to specific Service Accounts via the Trust Policy `Condition` block
 *   (e.g., `system:serviceaccount:namespace:service-account`).
 */

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

/*
 * -------------------
 * EBS CSI DRIVER ROLE
 * -------------------
 * Purpose:
 *   Grants the EBS CSI driver permission to provision and manage EBS volumes for Persistent Volume Claims (PVCs).
 *   This enables dynamic storage provisioning for stateful workloads within the cluster.
 *
 * Mechanism:
 *   - IRSA: The role is assumed by the `ebs-csi-controller-sa` service account in the `kube-system` namespace.
 *   - Policy: Uses the AWS managed policy `AmazonEBSCSIDriverPolicy` to handle EC2 volume lifecycle actions.
 */

locals {
  oidc_provider = replace(aws_iam_openid_connect_provider.eks.url, "https://", "")
}

module "ebs_csi_driver_role" {
  source = "../modules/identity-roles"

  iam_role_name        = local.EBS_CSI_ROLE_NAME
  iam_role_description = local.EBS_CSI_ROLE_DESC
  iam_role_trust_policy = templatefile("./templates/iam-eks-irsa-trust-policy.json", {
    OIDC_ARN        = aws_iam_openid_connect_provider.eks.arn
    OIDC_PROVIDER   = local.oidc_provider
    NAMESPACE       = "kube-system"
    SERVICE_ACCOUNT = "ebs-csi-controller-sa"
  })

  # Attach permission boundary and permission policies
  iam_role_permissions_boundary = module.eks_cluster_boundary.iam_policy_arn
  iam_role_policies             = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
}

/*
 * -----------------------------------
 * AWS LOAD BALANCER CONTROLLER POLICY
 * -----------------------------------
 * Purpose:
 *   Defines the custom permissions required by the AWS Load Balancer Controller to manage
 *   AWS Elastic Load Balancers (ALB/NLB), Target Groups, and Security Groups.
 *   This policy is based on the official AWS specification for the controller.
 *   Reference: https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/deploy/installation/#iam-permissions
 */

module "alb_controller_policy" {
  source = "../modules/identity-policies"

  iam_policy_name                 = local.ALB_CONTROLLER_POLICY_NAME
  iam_policy_description          = local.ALB_CONTROLLER_POLICY_DESC
  iam_policy_document             = file("./templates/iam-eks-alb-controller-policy.json")
  iam_policy_attachment_role_name = null
}

/*
 * ---------------------------------
 * AWS LOAD BALANCER CONTROLLER ROLE
 * ---------------------------------
 * Purpose:
 *   Empowers the AWS Load Balancer Controller to manage AWS Elastic Load Balancers (ALB/NLB)
 *   for Kubernetes Ingress and Service resources.
 *
 * Mechanism:
 *   - IRSA: Assumed by the `aws-load-balancer-controller` service account in the `kube-system` namespace.
 *   - Usage: Required when using `ingressClassName: alb` or `type: LoadBalancer` services.
 */

module "alb_controller_role" {
  source = "../modules/identity-roles"

  iam_role_name        = local.ALB_CONTROLLER_ROLE_NAME
  iam_role_description = local.ALB_CONTROLLER_ROLE_DESC
  iam_role_trust_policy = templatefile("./templates/iam-eks-irsa-trust-policy.json", {
    OIDC_ARN        = aws_iam_openid_connect_provider.eks.arn
    OIDC_PROVIDER   = local.oidc_provider
    NAMESPACE       = "kube-system"
    SERVICE_ACCOUNT = "aws-load-balancer-controller"
  })

  # Attach permission boundary and permission policies
  iam_role_permissions_boundary = null
  iam_role_policies             = [module.alb_controller_policy.iam_policy_arn]
}

/*
 * -------------------------
 * CLUSTER AUTOSCALER POLICY
 * -------------------------
 * Purpose:
 *   Defines the custom permissions required by the Cluster Autoscaler to inspect
 *   Auto Scaling Groups (ASGs) and modify their desired capacity.
 */

module "cluster_autoscaler_policy" {
  source = "../modules/identity-policies"

  iam_policy_name                 = local.AUTOSCALER_POLICY_NAME
  iam_policy_description          = local.AUTOSCALER_POLICY_DESC
  iam_policy_attachment_role_name = null
  iam_policy_document             = file("./templates/iam-eks-autoscaler-policy.json")
}

/*
 * -----------------------
 * CLUSTER AUTOSCALER ROLE
 * -----------------------
 * Purpose:
 *   Authorizes the Cluster Autoscaler to automatically adjust the size of the EKS node groups
 *   based on pod scheduling demands and resource utilization.
 *
 * Mechanism:
 *   - IRSA: Assumed by the `cluster-autoscaler` service account in the `kube-system` namespace.
 *   - Functionality:
 *       - Scale Up: Adds nodes when pods are in 'Pending' state due to insufficient resources.
 *       - Scale Down: Removes nodes that are underutilized to optimize costs.
 */

module "cluster_autoscaler_role" {
  source = "../modules/identity-roles"

  iam_role_name        = local.AUTOSCALER_ROLE_NAME
  iam_role_description = local.AUTOSCALER_ROLE_DESC
  iam_role_trust_policy = templatefile("./templates/iam-eks-irsa-trust-policy.json", {
    OIDC_ARN        = aws_iam_openid_connect_provider.eks.arn
    OIDC_PROVIDER   = local.oidc_provider
    NAMESPACE       = "kube-system"
    SERVICE_ACCOUNT = "cluster-autoscaler"
  })

  # Attach permission boundary and permission policies
  iam_role_permissions_boundary = module.eks_cluster_boundary.iam_policy_arn
  iam_role_policies             = [module.cluster_autoscaler_policy.iam_policy_arn]
}

/*
 * ---------------------
 * CLOUDWATCH AGENT ROLE
 * ---------------------
 * Purpose:
 *   Authorizes the CloudWatch Agent to publish metrics to CloudWatch (Container Insights).
 */

module "cloudwatch_agent_role" {
  source = "../modules/identity-roles"

  iam_role_name        = local.CW_AGENT_ROLE_NAME
  iam_role_description = local.CW_AGENT_ROLE_DESC
  iam_role_trust_policy = templatefile("./templates/iam-eks-irsa-trust-policy.json", {
    OIDC_ARN        = aws_iam_openid_connect_provider.eks.arn
    OIDC_PROVIDER   = local.oidc_provider
    NAMESPACE       = "amazon-cloudwatch"
    SERVICE_ACCOUNT = "cloudwatch-agent"
  })

  iam_role_permissions_boundary = module.eks_cluster_boundary.iam_policy_arn
  iam_role_policies             = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
}

/*
 * ---------------
 * FLUENT BIT ROLE
 * ---------------
 * Purpose:
 *   Authorizes Fluent Bit to push container logs to CloudWatch Logs.
 */

module "fluent_bit_role" {
  source = "../modules/identity-roles"

  iam_role_name        = local.FLUENT_BIT_ROLE_NAME
  iam_role_description = local.FLUENT_BIT_ROLE_DESC
  iam_role_trust_policy = templatefile("./templates/iam-eks-irsa-trust-policy.json", {
    OIDC_ARN        = aws_iam_openid_connect_provider.eks.arn
    OIDC_PROVIDER   = local.oidc_provider
    NAMESPACE       = local.K8S_ADMIN_NAMESPACE
    SERVICE_ACCOUNT = "fluent-bit"
  })

  iam_role_permissions_boundary = module.eks_cluster_boundary.iam_policy_arn
  iam_role_policies             = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
}

/*
 * ------------------------------------
 * IAM ROLE & GROUP FOR ADMIN NAMESPACE
 * ------------------------------------
 * Purpose:
 *   Creates an IAM Role that can be assumed by authorized users to access the admin namespace.
 *   Defines an IAM Group that grants its members permission to assume this role.
 */

module "admin_role" {
  source = "../modules/identity-roles"

  iam_role_name        = local.ADMIN_ROLE_NAME
  iam_role_description = local.ADMIN_ROLE_DESC
  iam_role_trust_policy = templatefile("./templates/iam-trust-policy-account-root.json", {
    ACCOUNT_ID = data.aws_caller_identity.current.account_id
  })
}

resource "aws_iam_group" "admin" {
  name = local.ADMIN_GROUP_NAME
}

module "kubernetes_admin_group_policy" {
  source = "../modules/identity-policies"

  iam_policy_name        = local.ADMIN_POLICY_NAME
  iam_policy_description = local.ADMIN_POLICY_DESC
  iam_policy_document = templatefile("./templates/iam-policy-assume-role.json", {
    ROLE_ARN = module.admin_role.iam_role_arn
  })

  iam_policy_attachment_group_name = aws_iam_group.admin.name
}
