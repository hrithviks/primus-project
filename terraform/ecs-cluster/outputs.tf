/*
 * Script Name  : outputs.tf
 * Project Name : Primus
 * Description  : Exposes key infrastructure attributes as Terraform outputs.
 *                These values are intended for use by downstream systems, CI/CD pipelines,
 *                or for operator reference.
 */

output "ecs_cluster_id" {
  description = "The unique identifier of the ECS cluster."
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "vpc_id" {
  description = "The ID of the VPC where the cluster is deployed."
  value       = module.main_vpc.vpc_id
}

output "opensearch_secret_arn" {
  description = "The ARN of the Secrets Manager secret containing the OpenSearch initial admin password."
  value       = aws_secretsmanager_secret.opensearch_admin_password.arn
}

output "opensearch_endpoint" {
  description = "The public HTTP endpoint for the OpenSearch API."
  value       = "http://${module.app_load_balancer.alb_dns_name}:9200"
}

output "dashboards_endpoint" {
  description = "The public URL for the OpenSearch Dashboards user interface."
  value       = "http://${module.app_load_balancer.alb_dns_name}/dashboards"
}

output "logstash_endpoint" {
  description = "The public HTTP endpoint for Logstash ingestion."
  value       = "http://${module.app_load_balancer.alb_dns_name}/logstash"
}
