/*
 * Script Name  : main.tf
 * Project Name : Primus
 * Description  : Defines ECS Task Definition and Service.
 * Scope        : Module (ECS Task)
 */

resource "aws_ecs_task_definition" "main" {
  family                   = var.ecs_task_family_name
  network_mode             = var.ecs_task_network_mode
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn
  container_definitions    = var.ecs_task_container_definitions

  # Attach EFS Volume
  # Add more details here on implementation
  dynamic "volume" {
    for_each = var.ecs_volume_config != null ? [var.ecs_volume_config] : []
    content {
      name = volume.value.name
      efs_volume_configuration {
        file_system_id     = volume.value.file_system_id
        root_directory     = volume.value.root_directory
        transit_encryption = volume.value.access_point_id != null ? "ENABLED" : "DISABLED"

        dynamic "authorization_config" {
          for_each = volume.value.access_point_id != null ? [1] : []
          content {
            access_point_id = volume.value.access_point_id
            iam             = "ENABLED"
          }
        }
      }
    }
  }
}

resource "aws_ecs_service" "main" {
  name                              = var.ecs_name
  cluster                           = var.ecs_cluster_id
  task_definition                   = aws_ecs_task_definition.main.arn
  desired_count                     = var.ecs_task_desired_count
  launch_type                       = var.ecs_launch_type
  health_check_grace_period_seconds = var.ecs_target_group_arn != null ? var.ecs_health_check_grace_period_seconds : null

  # Network configuration
  # Add more details here on implementation
  network_configuration {
    subnets         = var.ecs_subnet_ids
    security_groups = var.ecs_security_group_ids
  }

  # Service Registry configuration
  # Add more details here on implementation
  dynamic "service_registries" {
    for_each = var.ecs_service_registry_arn != null ? [var.ecs_service_registry_arn] : []
    content {
      registry_arn = service_registries.value
    }
  }

  # Load Balancer configuration
  # Add more details here on implementation
  dynamic "load_balancer" {
    for_each = concat(
      var.ecs_target_group_arn != null ? [{
        target_group_arn = var.ecs_target_group_arn
        container_port   = var.ecs_container_port
        container_name   = var.ecs_name
      }] : [],
      var.ecs_load_balancers
    )
    content {
      target_group_arn = load_balancer.value.target_group_arn
      container_name   = coalesce(load_balancer.value.container_name, var.ecs_name)
      container_port   = load_balancer.value.container_port
    }
  }
}
