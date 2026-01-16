/*
 * Script Name: 07-kubernetes.tf
 * Project Name: Primus
 * Description: Manages native Kubernetes resources using the Terraform Kubernetes provider.
 * This includes Namespaces, Resource Quotas, and other non-Helm constructs.
 *
 * ---------------------
 * Dependency Management:
 * ---------------------
 * - Admin Namespace: Depends on the EKS Access Policy Association to ensure the Terraform user has permissions to create resources.
 */

/*
 * ---------------
 * ADMIN NAMESPACE
 * ---------------
 * Purpose:
 *   Creates a dedicated namespace for administrative workloads and observability tools
 *   (e.g., Fluent Bit, monitoring agents) to isolate them from application logic.
 *
 * Configuration:
 *   - Name: Prefixed with the project name (e.g., primus-dev-admin).
 */

resource "kubernetes_namespace_v1" "admin" {
  metadata {
    name = local.K8S_ADMIN_NAMESPACE

    labels = {
      name = local.K8S_ADMIN_NAMESPACE
      role = "administration"
    }
  }

  depends_on = [
    aws_eks_access_policy_association.main,
    aws_eks_node_group.main
  ]
}

/*
 * --------------------
 * ADMIN NAMESPACE RBAC
 * --------------------
 * Purpose:
 *   Binds the Kubernetes 'admin' ClusterRole to a specific group within the admin namespace.
 *   This allows users belonging to this group to manage resources fully within this namespace,
 *   without having cluster-wide admin privileges.
 */

resource "kubernetes_role_binding_v1" "admin_group" {
  metadata {
    name      = local.K8S_ADMIN_BINDING_NAME
    namespace = kubernetes_namespace_v1.admin.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }

  subject {
    kind      = "Group"
    name      = local.ADMIN_GROUP_NAME
    api_group = "rbac.authorization.k8s.io"
  }
}

/*
 * ----------------------
 * ADMIN NAMESPACE ACCESS
 * ----------------------
 * Purpose:
 *   Configures EKS Access Entries to grant access to principals associated to Admin group
 *
 * Configuration:
 *   - Principal: Maps the IAM entity to the cluster authentication layer.
 *   - Policy: Associates the `AmazonEKSClusterAdminPolicy` scoped strictly to the admin namespace.
 */
resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = module.admin_role.iam_role_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.admin.principal_arn

  # Kubernetes level scoping (e.g Namespace)
  access_scope {
    type       = "namespace"
    namespaces = [kubernetes_namespace_v1.admin.metadata[0].name]
  }
}

/*
 * -------------
 * STORAGE CLASS
 * -------------
 * Purpose:
 *   Defines the 'gp3' StorageClass for dynamic volume provisioning via the EBS CSI Driver.
 *   Marked as default so PVCs without a specific className will use it automatically.
 */
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type = "gp3"
  }
  depends_on = [
    aws_eks_access_policy_association.main,
    aws_eks_node_group.main,
    aws_eks_addon.ebs_csi_driver
  ]
}
