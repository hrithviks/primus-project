/*
 * Script Name  : main.tf
 * Project Name : Primus
 * Description  : Provisions IAM Policies and manages their association with IAM Roles.
 *                This module is designed to be reusable, allowing for the creation of
 *                standalone policies or policies immediately attached to a specific role.
 * Scope        : Module (IAM/Policy)
 */

/*
 * ---------------------
 * IAM POLICY DEFINITION
 * ---------------------
 * Purpose:
 *   Defines the permissions document in JSON format and creates the IAM Policy resource in AWS.
 */

resource "aws_iam_policy" "main" {
  name        = var.iam_policy_name
  description = var.iam_policy_description
  policy      = var.iam_policy_document
}

/*
 * -----------------
 * POLICY ATTACHMENT
 * -----------------
 * Purpose:
 *   Optionally attaches the created policy to a specified IAM Role.
 *
 * Logic:
 *   - If `var.iam_policy_attachment_role_name` is not null, creates 1 attachment.
 *   - If null, creates 0 attachments.
 */

resource "aws_iam_role_policy_attachment" "main" {
  count      = var.iam_policy_attachment_role_name != null ? 1 : 0
  role       = var.iam_policy_attachment_role_name
  policy_arn = aws_iam_policy.main.arn
}

resource "aws_iam_group_policy_attachment" "main" {
  count      = var.iam_policy_attachment_group_name != null ? 1 : 0
  group      = var.iam_policy_attachment_group_name
  policy_arn = aws_iam_policy.main.arn
}
