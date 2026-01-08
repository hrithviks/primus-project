# Primus

**Primus** is a centralized container orchestration platform designed to host multiple distinct projects with high isolation and resilient observability.

## Architecture Overview

*   **Application Plane**: Amazon EKS (Elastic Kubernetes Service) for workloads.
*   **Observability Plane**: Amazon ECS (Fargate) hosting the ELK stack (OpenSearch, Logstash, Dashboards).

## Documentation Strategy

Detailed architectural decisions, security implementations, and configuration options are documented **directly within the Terraform source files**. This ensures that documentation evolves alongside the infrastructure code.

Please refer to the file headers in `terraform/ecs-cluster/` for in-depth explanations of:
*   **Networking**: `main-vpc.tf`
*   **Security**: `main-ecs-security.tf`
*   **Storage & Compute**: `main-ecs.tf`
*   **Services**: `main-opensearch.tf`, `main-dashboard.tf`, `main-logstash.tf`

## Deployment

```bash
cd terraform/ecs-cluster
terraform init
terraform apply
```