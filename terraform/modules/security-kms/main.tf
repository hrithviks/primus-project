/*
 * Script Name  : main.tf
 * Project Name : Primus
 * Description  : Main configuration for the KMS module.
 * Scope        : Module (KMS)
 */

resource "aws_kms_key" "main" {
  description             = var.kms_description
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = var.kms_enable_key_rotation
  policy                  = data.aws_iam_policy_document.main.json
}

resource "aws_kms_alias" "main" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.main.key_id
}

data "aws_iam_policy_document" "main" {

  # Allows admin user to manage the key
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.kms_admin_account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  # Allows CloudWatch Logs to encrypt/decrypt data
  statement {
    sid    = "Allow CloudWatch Logs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${var.kms_account_region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*"
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.kms_account_region}:${var.kms_admin_account_id}:log-group:*"]
    }
  }
}
