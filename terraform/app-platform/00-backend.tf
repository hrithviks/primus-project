/*
 * Script Name: backend.tf
 * Project Name: Primus
 * Description: Configures the Terraform backend to store state files in a remote S3 bucket.
 * This ensures state consistency, enables collaboration, and provides security
 * through encryption and locking mechanisms.
 *
 * Configuration Details:
 * - Backend Type: S3 (Simple Storage Service).
 * - State Storage: Stores the `terraform.tfstate` file in the specified S3 bucket path.
 * - Region: The S3 bucket is located in `ap-southeast-1`.
 * - Encryption: State files are encrypted at rest (`encrypt = true`) to protect sensitive data.
 * - State Locking: Uses S3 native locking (`use_lockfile = true`) to prevent concurrent modifications.
 *
 * Usage Guidelines:
 * - Initialization: Run `terraform init` to initialize the backend.
 * - CI/CD Pipeline: For dynamic environments, it is recommended to use partial configuration
 * and pass backend settings via command-line arguments:
 * `terraform init -backend-config="bucket=<BUCKET_NAME>" -backend-config="key=<KEY_PATH>"`
 */

terraform {
  backend "s3" {
    # Specifies the target S3 bucket for centralized state storage.
    bucket = "primus-app-stack-bucket"

    # Defines the specific path (key for demonstration) within the bucket for the state file.
    # Note: Pipeline execution roles are restricted from accessing this specific key path
    # to enforce partial configuration.
    key = "terraform/build/terraform.tfstate"

    # The AWS region hosting the S3 bucket.
    region = "ap-southeast-1"

    # Activates server-side encryption to secure state data at rest.
    encrypt = true

    # Utilizes S3 native locking mechanisms (introduced in Terraform 1.10) to prevent race conditions.
    # This replaces the legacy approach which required a separate DynamoDB table for locking.
    # Note: When defining IAM policies, ensure permissions cover both the state file and the lock file
    # (e.g., `terraform.tfstate` and `terraform.tfstate.tflock`).
    use_lockfile = true
  }
}
