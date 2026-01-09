/*
 * Script Name: outputs.tf
 * Project Name: Primus
 * Description: Defines the output values exported by the EKS cluster module.
 * These outputs provide essential connection details and identifiers required
 * for configuring `kubectl` and integrating with other infrastructure components.
 *
 * Output Details:
 * - Cluster Endpoint: The URL of the EKS control plane API server.
 * - Cluster Name: The unique identifier of the provisioned Kubernetes cluster.
 * - Kubectl Config: A convenience command to automatically update the local kubeconfig
 * file for immediate cluster access.
 */

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = aws_eks_cluster.main.name
}

output "configure_kubectl" {
  description = "Configure kubectl: this command can be used to configure kubectl to connect to the cluster."
  value       = "aws eks update-kubeconfig --name ${aws_eks_cluster.main.name} --region ${var.main_aws_region}"
}
