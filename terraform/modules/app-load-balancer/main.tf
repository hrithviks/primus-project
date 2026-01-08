/*
 * Script Name  : main.tf
 * Project Name : Primus
 * Description  : Defines Application Load Balancer and default listener.
 * Scope        : Module (ALB)
 */

resource "aws_lb" "main" {
  name                       = var.alb_name
  internal                   = var.alb_internal
  load_balancer_type         = "application"
  security_groups            = var.alb_security_group_ids
  subnets                    = var.alb_subnet_ids
  enable_deletion_protection = var.alb_enable_deletion_protection

  tags = {
    Name = var.alb_name
  }
}

resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = var.alb_listener_port
  protocol          = var.alb_listener_protocol

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}
