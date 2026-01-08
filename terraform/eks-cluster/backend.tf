/*
 * Script Name  : backend.tf
 * Project Name : Primus
 * Description  : Configures S3 backend for secure state storage - 
                  for EKS cluster
 * Scope        : Root
 */

terraform {
  backend "s3" {
    bucket       = "primus-app-stack-bucket"
    key          = "terraform/build/terraform.tfstate"
    region       = "ap-southeast-1"
    encrypt      = true
    use_lockfile = true
  }
}
