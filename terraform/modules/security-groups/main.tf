/*
 * Script Name  : main.tf
 * Project Name : Primus
 * Description  : Defines the Security group resource with attachment to a role
 * Scope        : Module (Security Groups)
 */

resource "aws_security_group" "main" {
  name        = var.sg_name
  description = var.sg_description
  vpc_id      = var.sg_vpc_id

  tags = {
    Name = var.sg_name
  }
}

/*
 * -----------------------------
 * SECURITY GROUP INGRESS RULES
 * -----------------------------
 * Iterates over the provided ingress rules map to create individual security group rules.
 * This resource manages inbound traffic permissions for the security group.
 */
resource "aws_security_group_rule" "ingress" {
  for_each = var.sg_ingress_rules

  type              = "ingress"
  security_group_id = aws_security_group.main.id

  description              = each.value.description
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  cidr_blocks              = each.value.cidr_blocks
  source_security_group_id = each.value.source_security_group_id
  self                     = each.value.self
}

/*
 * -----------------------------
 * SECURITY GROUP EGRESS RULES
 * -----------------------------
 * Iterates over the provided egress rules map to create individual security group rules.
 * This resource manages outbound traffic permissions for the security group.
 */
resource "aws_security_group_rule" "egress" {
  for_each = var.sg_egress_rules

  type              = "egress"
  security_group_id = aws_security_group.main.id

  description              = each.value.description
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  cidr_blocks              = each.value.cidr_blocks
  source_security_group_id = each.value.source_security_group_id
  self                     = each.value.self
}
