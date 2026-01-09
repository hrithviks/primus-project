/*
 * Script Name  : main.tf
 * Project Name : Primus
 * Description  : Provisions IAM Roles and manages their trust relationships.
 *                This module abstracts the creation of IAM roles, ensuring consistent
 *                tagging and optional permission boundary enforcement.
 * Scope        : Module (IAM Role)
 */

/*
 * -------------------
 * IAM ROLE DEFINITION
 * -------------------
 * Purpose:
 *   Creates an IAM Role that can be assumed by trusted entities (users, services, or accounts).
 *
 * Configuration:
 *   - Trust Policy        : Defines who can assume this role (AssumeRolePolicyDocument).
 *   - Permissions Boundary: Optional ARN of a policy to limit the maximum permissions of the role.
 */

resource "aws_iam_role" "main" {
  name               = var.iam_role_name
  description        = var.iam_role_description
  assume_role_policy = var.iam_role_trust_policy
  tags               = var.iam_role_tags

  # Optional permissions boundary (expects an ARN)
  permissions_boundary = var.iam_role_permissions_boundary
}

/*
 * -----------------
 * POLICY ATTACHMENT
 * -----------------
 * Purpose:
 *   Attaches a list of existing IAM policies (AWS Managed or Customer Managed) to the role.
 *   This allows attaching multiple policies without defining separate resources for each.
 *
 * Logic:
 *   - Iterates over the `var.iam_role_policies` list using `count`.
 *   - Creates an attachment for each ARN provided.
 */

resource "aws_iam_role_policy_attachment" "main" {
  count      = length(var.iam_role_policies)
  role       = aws_iam_role.main.name
  policy_arn = var.iam_role_policies[count.index]
}
