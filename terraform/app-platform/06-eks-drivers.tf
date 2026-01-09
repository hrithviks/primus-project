/*
 * Script Name: 06-eks-drivers.tf
 * Project Name: Primus
 * Description: Manages EKS Add-ons and operational components.
 * Ensures essential cluster services are installed, version-controlled,
 * and integrated with IAM roles where necessary.
 *
 * ------------------------
 * Architectural Decisions:
 * ------------------------
 * - Managed Add-ons: Leverages EKS Managed Add-ons for VPC CNI, CoreDNS, Kube-proxy,
 * EBS CSI Driver, and AWS Load Balancer Controller to simplify lifecycle management.
 * - Dynamic Versioning: Automatically retrieves the latest compatible add-on versions
 * for the specific EKS cluster version.
 * - Security (IRSA): The EBS CSI Driver is associated with an IAM Role for Service Accounts
 * (IRSA) to grant granular permissions for volume management.
 *
 * ---------------------
 * Dependency Management:
 * ---------------------
 * - CoreDNS: Waits for VPC CNI and Node Group to ensure networking is ready.
 * - EBS CSI Driver: Waits for CoreDNS to ensure DNS resolution for AWS APIs (STS).
 */

/*
 * -------
 * VPC CNI
 * -------
 * Purpose:
 *   The Amazon VPC CNI plugin for Kubernetes allows Pods to have the same IP address
 *   inside the pod as they do on the VPC network.
 *
 * Configuration:
 *   - Versioning: Dynamically fetches the most recent version compatible with the cluster.
 *
 * Feature: Prefix Delegation
 * --------------------------
 *   Enables the VPC CNI to assign a /28 prefix (16 IPs) to each ENI slot instead of a single IP.
 *   This significantly increases the number of Pods that can run on smaller instance types (e.g., t3.small).
 *
 *   - Settings:
 *     - ENABLE_PREFIX_DELEGATION: "true" activates this mode.
 *     - WARM_PREFIX_TARGET: "1" ensures at least one full /28 prefix is attached.
 *
 *   - Pros: Overcomes strict Pod density limits (e.g., t3.small limit increases from 11 to ~110).
 *   - Cons: Consumes IPs in blocks of 16. Requires appropriately sized subnets.
 */

data "aws_eks_addon_version" "vpc_cni" {
  addon_name         = "vpc-cni"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "vpc-cni"
  addon_version = data.aws_eks_addon_version.vpc_cni.version

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION = "true"
      WARM_PREFIX_TARGET       = "1"
    }
  })
}

/*
 * --------
 * CORE DNS
 * --------
 * Purpose:
 *   CoreDNS is a flexible, extensible DNS server that serves as the cluster DNS.
 *   It provides name resolution for Services and Pods.
 *
 * Configuration:
 *   - Dependency: Explicitly depends on the Node Group because CoreDNS Pods require
 *   compute resources (worker nodes) to be scheduled and run.
 */

data "aws_eks_addon_version" "coredns" {
  addon_name         = "coredns"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "coredns"
  addon_version = data.aws_eks_addon_version.coredns.version

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_addon.vpc_cni
  ]
}

/*
 * ----------
 * KUBE PROXY
 * ----------
 * Purpose:
 *   Maintains network rules on each Amazon EC2 node. It enables network communication
 *   to Pods from inside and outside of the cluster.
 */

data "aws_eks_addon_version" "kube_proxy" {
  addon_name         = "kube-proxy"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = aws_eks_cluster.main.name
  addon_name    = "kube-proxy"
  addon_version = data.aws_eks_addon_version.kube_proxy.version
}

/*
 * --------------
 * EBS CSI DRIVER
 * --------------
 * Purpose:
 *   The Amazon Elastic Block Store (EBS) Container Storage Interface (CSI) driver
 *   allows the cluster to manage the lifecycle of EBS volumes for persistent storage.
 *
 * Configuration:
 *   - Permissions: Uses IRSA (IAM Roles for Service Accounts) to grant the driver
 *   permissions to make AWS API calls (create/delete volumes).
 */

data "aws_eks_addon_version" "ebs_csi_driver" {
  addon_name         = "aws-ebs-csi-driver"
  kubernetes_version = aws_eks_cluster.main.version
  most_recent        = true
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = data.aws_eks_addon_version.ebs_csi_driver.version
  service_account_role_arn = module.ebs_csi_driver_role.iam_role_arn

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_addon.coredns
  ]
}
