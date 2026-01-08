/*
 * Script Name  : variables.tf
 * Project Name : Primus
 * Description  : Defines input variables for the Application Load Balancer module.
 * Scope        : Module (ALB)
 */

variable "alb_name" {
  description = "The name of the Application Load Balancer"
  type        = string
}

variable "alb_internal" {
  description = "Boolean determining if the load balancer is internal or external"
  type        = bool
  default     = false
}

variable "alb_security_group_ids" {
  description = "List of security group IDs to assign to the ALB"
  type        = list(string)
}

variable "alb_subnet_ids" {
  description = "List of subnet IDs to attach to the ALB"
  type        = list(string)
}

variable "alb_enable_deletion_protection" {
  description = "If true, deletion of the load balancer will be disabled via the AWS API"
  type        = bool
  default     = false
}

variable "alb_listener_port" {
  description = "The port on which the load balancer is listening"
  type        = number
  default     = 80
}

variable "alb_listener_protocol" {
  description = "The protocol for connections from clients to the load balancer"
  type        = string
  default     = "HTTP"
}
