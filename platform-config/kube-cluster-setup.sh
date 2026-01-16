#!/bin/bash
# -----------------------------------------------------------------------------
# Script Name : primus-cluster-setup.sh
# Description : Dedicated bootstrap script to install dependent Helm packages.
# Usage       : ./primus-cluster-setup.sh
# -----------------------------------------------------------------------------

# Enable strict error handling
set -euo pipefail

# Register Helm repositories
echo "Registering Helm repositories..."
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add argo https://argoproj.github.io/argo-helm

# Update repository cache
helm repo update

# Create Namespaces
# Ensures required namespaces exist before Helm chart installation.
echo "Creating namespaces..."
for ns in primus-kyverno primus-argocd; do
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -
done

# Deploy Kyverno
# Configured for High Availability with multiple replicas for admission controllers.
# - admissionController.replicas=3: Ensures webhooks are responsive during node upgrades.
# - extraArgs: Enables PolicyExceptions to exempt specific resources from policies.
# - global.image.registry: Uses GHCR to avoid Docker Hub rate limits.
echo "Deploying Kyverno..."
helm upgrade --install kyverno kyverno/kyverno -n primus-kyverno \
  --wait \
  --set global.image.registry="ghcr.io" \
  --set admissionController.replicas=1 \
  --set backgroundController.replicas=1 \
  --set cleanupController.replicas=1 \
  --set reportsController.replicas=1 \
  --set admissionController.extraArgs={--enablePolicyException=true}

# Deploy Metrics Server
# Required for Horizontal Pod Autoscaling (HPA).
# Note: --kubelet-insecure-tls is enabled to bypass certificate validation in this environment.
echo "Deploying Metrics Server..."
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system \
  --wait \
  --set args={--kubelet-insecure-tls}

# Deploy ArgoCD - Configured for single-node compatibility (HA disabled).
# - server/repoServer replicas: Scales UI/API and Git operations for high traffic.
# - controller.replicas=1: Kept as singleton (Active-Passive) to avoid sharding complexity.
# - timeout: Increased to 10m to allow persistent volumes and HA components to initialize.
echo "Deploying ArgoCD..."
helm upgrade --install argocd argo/argo-cd -n primus-argocd \
  --wait \
  --timeout 10m \
  --set redis-ha.enabled=false \
  --set redis-ha.haproxy.enabled=false \
  --set controller.replicas=1 \
  --set server.replicas=1 \
  --set repoServer.replicas=1 \
  --set applicationSet.replicas=1

# Deploy ArgoCD Ingress
# Uses the AWS Load Balancer Controller (installed via Terraform).
# Note: Requires a valid ACM Certificate ARN for HTTPS.
# Logic: Only deploy Ingress on non-local clusters (e.g., EKS).
CURRENT_CONTEXT=$(kubectl config current-context)
IS_LOCAL=false

if [[ "$CURRENT_CONTEXT" == "docker-desktop" ]]; then
  echo "Local environment detected ($CURRENT_CONTEXT). Skipping Ingress deployment."
  IS_LOCAL=true
else
  echo "Deploying ArgoCD Ingress..."
  kubectl apply -f "argo-ingress-ctrl.yaml"
fi

# Post-Installation Instructions
echo "----------------------------------------------------------------"
echo "ArgoCD Installation Complete"
echo "----------------------------------------------------------------"
echo "1. Retrieve the initial admin password:"
echo "   kubectl -n primus-argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""

if [[ "$IS_LOCAL" == "true" ]]; then
  echo "2. Access the UI (Port Forward):"
  echo "   kubectl port-forward svc/argocd-server -n primus-argocd 8080:443"
  echo "   URL: https://localhost:8080 (User: admin)"
else
  echo "2. Access the UI (Ingress):"
  echo "   Wait for the Load Balancer to provision (approx. 2-5 mins)."
  echo "   Check URL: kubectl get ingress argocd-server -n primus-argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
fi
echo "----------------------------------------------------------------"