/*
 * Script Name  : variables.tf
 * Project Name : Primus
 * Description  : Defines input variables for the ECS Task module.
 * Scope        : Module (ECS Task)
 */

variable "ecs_task_family_name" {
  description = "The ECS task family name"
  type        = string
}

variable "ecs_task_network_mode" {
  description = "The ECS task network mode"
  type        = string
  default     = "awsvpc"
}

variable "ecs_task_cpu" {
  description = "The number of cpu units used by the task"
  type        = number
}

variable "ecs_task_memory" {
  description = "The amount (in MiB) of memory used by the task"
  type        = number
}

variable "ecs_task_execution_role_arn" {
  description = "ARN of the task execution role"
  type        = string
}

variable "ecs_task_role_arn" {
  description = "ARN of the task role"
  type        = string
}

variable "ecs_task_container_definitions" {
  description = "JSON container definitions"
  type        = string
}

variable "ecs_name" {
  description = "Name of the service/task"
  type        = string
}

variable "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  type        = string
}

variable "ecs_task_desired_count" {
  description = "Number of instances of the task definition"
  type        = number
  default     = 1
}

variable "ecs_launch_type" {
  description = "Launch type for the service"
  type        = string
  default     = "FARGATE"
}

variable "ecs_subnet_ids" {
  description = "List of subnets for the service"
  type        = list(string)
}

variable "ecs_security_group_ids" {
  description = "List of security groups for the service"
  type        = list(string)
}

variable "ecs_service_registry_arn" {
  description = "ARN of the service registry (CloudMap)"
  type        = string
  default     = null
}

variable "ecs_volume_config" {
  description = "Configuration for EFS volume"
  type = object({
    name            = string
    file_system_id  = string
    root_directory  = string
    access_point_id = string
  })
  default = null
}

variable "ecs_target_group_arn" {
  description = "The ARN of the Load Balancer Target Group to attach to the service."
  type        = string
  default     = null
}

variable "ecs_container_port" {
  description = "The port on the container to allow via the load balancer."
  type        = number
  default     = null
}

variable "ecs_health_check_grace_period_seconds" {
  description = "Seconds to ignore failing load balancer health checks on newly instantiated tasks"
  type        = number
  default     = 0
}
