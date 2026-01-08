/*
 * Script Name  : outputs.tf
 * Project Name : Primus
 * Description  : Defines outputs for the Application Load Balancer module.
 * Scope        : Module (ALB)
 */

output "alb_arn" {
  description = "The ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "The canonical hosted zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "alb_listener_arn" {
  description = "The ARN of the load balancer listener"
  value       = aws_lb_listener.main.arn
}
