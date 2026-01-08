/*
 * Script Name  : outputs.tf
 * Project Name : Primus
 * Description  : Outputs for the ECS Task module.
 * Scope        : Module (ECS Task)
 */

output "task_definition_arn" {
  description = "ARN of the task definition"
  value       = aws_ecs_task_definition.main.arn
}

