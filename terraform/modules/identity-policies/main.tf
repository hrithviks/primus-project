/*
 * Script Name  : main.tf
 * Project Name : Primus
 * Description  : Defines the IAM policy resource with attachment to a role
 * Scope        : Module (IAM/Policy)
 */

resource "aws_iam_policy" "main" {
  name        = var.iam_policy_name
  description = var.iam_policy_description
  policy      = var.iam_policy_document
}

resource "aws_iam_role_policy_attachment" "main" {
  role       = var.iam_policy_attachment_role_name
  policy_arn = aws_iam_policy.main.arn
}
