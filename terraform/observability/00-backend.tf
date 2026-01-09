/*
 * Script Name: backend.tf
 * Project Name: Primus
 * Description: Configures the Terraform backend to store state in an AWS S3 bucket.
 * This configuration ensures state persistence, consistency, and security
 * through encryption and locking mechanisms.
 *
 * Configuration Details:
 * - S3 Bucket: Centralized storage for Terraform state files.
 * - State Key: Unique path for the state file within the bucket.
 * - Encryption: Enforced server-side encryption (SSE) to protect sensitive state data.
 * - Locking: Native S3 locking is enabled to prevent concurrent state modifications.
 *
 * Usage Guidelines:
 * - Initialization: Run `terraform init` to initialize the backend.
 * - CI/CD Pipeline: For dynamic environments, it is recommended to use partial configuration
 * and pass backend settings via command-line arguments:
 * `terraform init -backend-config="bucket=<BUCKET_NAME>" -backend-config="key=<KEY_PATH>"`
 */

terraform {
  backend "s3" {
    # The name of the S3 bucket used for storing Terraform state.
    bucket = "primus-observability-bucket"

    # The path to the state file inside the bucket.
    # IAM role for terraform execution via pipeline will be explicitly denied
    # access to the below key.
    key = "terraform/build/terraform.tfstate"

    # The AWS region where the S3 bucket is located.
    region = "ap-southeast-1"

    # Enables server-side encryption of the state file.
    encrypt = true

    # Utilizes S3 native locking mechanisms (introduced in Terraform 1.10) to prevent race conditions.
    # This replaces the legacy approach which required a separate DynamoDB table for locking.
    # Note: When defining IAM policies, ensure permissions cover both the state file and the lock file
    # (e.g., `terraform.tfstate` and `terraform.tfstate.tflock`).
    use_lockfile = true
  }
}
