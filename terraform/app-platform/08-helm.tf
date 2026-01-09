/*
 * Script Name: 08-helm.tf
 * Project Name: Primus
 * Description: Manages third-party applications and controllers using Helm Charts.
 * This includes operational tools like the Cluster Autoscaler and logging agents.
 *
 * ------------------------
 * Architectural Decisions:
 * ------------------------
 * - Cluster Autoscaler: Deployed in `kube-system` to match the IAM Role trust policy defined in 03-identity.tf.
 * It uses IRSA to securely access AWS Auto Scaling APIs.
 * - Fluent Bit: Deployed in the custom Admin namespace to separate logging infrastructure
 * from business applications.
 *
 * ---------------------
 * Dependency Management:
 * ---------------------
 * - General: All charts wait for the Node Group (compute) and CoreDNS (networking/DNS).
 * - Prometheus: Explicitly waits for the AWS Load Balancer Controller to ensure webhooks are ready.
 * - Grafana: Waits for Prometheus to ensure the datasource is available.
 */

/*
 * ------------------
 * CLUSTER AUTOSCALER
 * ------------------
 * Purpose:
 *   Automatically adjusts the size of the EKS Node Groups.
 *   - Scales UP when Pods fail to schedule due to insufficient resources.
 *   - Scales DOWN when nodes are underutilized.
 *
 * Architecture & Behavior:
 *   - Deployment: Runs as a Deployment (typically 1 replica) in the `kube-system` namespace.
 *   - RBAC: The chart automatically creates a `ClusterRole` and `ClusterRoleBinding`.
 *     This grants the autoscaler permission to read resource usage (Pods, Nodes) across
 *     the entire cluster to make scaling decisions.
 *   - Cloud Provider: Connects to AWS Auto Scaling Groups via the AWS SDK. Authentication
 *     is handled via IRSA (IAM Roles for Service Accounts).
 *
 * Configuration:
 *   - Namespace: `kube-system` (Mandated by the IRSA Trust Policy).
 *   - IRSA: Annotates the Service Account with the IAM Role ARN.
 */

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.43.2" # Ensure compatibility with EKS 1.34

  values = [
    yamlencode({
      autoDiscovery = {
        clusterName = aws_eks_cluster.main.name
      }
      awsRegion = var.main_aws_region
      rbac = {
        serviceAccount = {
          name = "cluster-autoscaler"
          annotations = {
            "eks.amazonaws.com/role-arn" = module.cluster_autoscaler_role.iam_role_arn
          }
        }
      }
    })
  ]

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_access_policy_association.main,
    aws_eks_addon.coredns
  ]
}

/*
 * ----------------------------
 * AWS LOAD BALANCER CONTROLLER
 * ----------------------------
 * Purpose:
 *   Manages AWS Elastic Load Balancers for Kubernetes Ingress and Service resources.
 *   Replaces the EKS Managed Add-on to ensure compatibility with newer K8s versions.
 *
 * Architecture & Behavior:
 *   - Deployment: Runs as a Deployment in `kube-system`.
 *   - Integration: Watches for Ingress events and provisions ALBs accordingly.
 *   - Security: Uses IRSA to authenticate with AWS APIs.
 */

resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  values = [
    yamlencode({
      clusterName = aws_eks_cluster.main.name
      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.alb_controller_role.iam_role_arn
        }
      }
    })
  ]

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_access_policy_association.main,
    aws_eks_addon.coredns
  ]
}

/*
 * ----------
 * FLUENT BIT
 * ----------
 * Purpose:
 *   A lightweight log processor and forwarder.
 *   Collects logs from Pods and sends them to Amazon CloudWatch Logs.
 *
 * Architecture & Behavior:
 *   - DaemonSet: Deployed as a DaemonSet, ensuring one Fluent Bit pod runs on every
 *     worker node in the cluster.
 *   - Log Collection: Mounts the host node's `/var/log/containers` directory to read
 *     log files directly from the file system.
 *   - RBAC: Uses a `ClusterRole` to query Kubernetes API for Pod metadata (names, labels, namespaces)
 *     to enrich the logs before sending them.
 *   - Output: Configured to push logs to CloudWatch Logs and optionally OpenSearch.
 *
 * Configuration:
 *   - Namespace: Deployed into the custom Admin namespace.
 *   - Chart: Uses `aws-for-fluent-bit` (AWS optimized version).
 */

resource "helm_release" "fluent_bit" {
  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  namespace  = kubernetes_namespace_v1.admin.metadata[0].name
  version    = "0.1.34" # Pinning version for stability

  values = [
    yamlencode({
      serviceAccount = {
        name = "fluent-bit"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.fluent_bit_role.iam_role_arn
        }
      }
      cloudWatch = {
        region       = var.main_aws_region
        logGroupName = "/aws/eks/${aws_eks_cluster.main.name}/workloads"
      }
      additionalOutputs = <<EOT
[OUTPUT]
    Name   http
    Match  *
    Host   ${var.logstash_host}
    Port   8080
    URI    /
    Format json
EOT
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.admin,
    aws_eks_node_group.main,
    aws_eks_addon.coredns
  ]
}

/*
 * ----------------
 * CLOUDWATCH AGENT
 * ----------------
 * Purpose:
 *   Collects system metrics (CPU, Memory, Disk) for Container Insights.
 *
 * Architecture & Behavior:
 *   - Namespace: Deployed into a dedicated `amazon-cloudwatch` namespace to isolate
 *     AWS-specific monitoring agents.
 *   - DaemonSet: Runs as a DaemonSet to collect infrastructure metrics from every node.
 *   - RBAC: Creates a `ClusterRole` to access the Kubelet API and cAdvisor for
 *     gathering container performance metrics.
 *   - IRSA: Uses the `cloudwatch-agent` service account to authenticate with AWS APIs
 *     and publish metrics to CloudWatch.
 */

resource "helm_release" "cloudwatch_agent" {
  name             = "aws-cloudwatch-metrics"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-cloudwatch-metrics"
  namespace        = "amazon-cloudwatch"
  create_namespace = true
  version          = "0.0.11"

  values = [
    yamlencode({
      clusterName = aws_eks_cluster.main.name
      serviceAccount = {
        name = "cloudwatch-agent"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.cloudwatch_agent_role.iam_role_arn
        }
      }
    })
  ]

  depends_on = [
    aws_eks_node_group.main,
    aws_eks_access_policy_association.main,
    aws_eks_addon.coredns
  ]
}

/*
 * ----------
 * PROMETHEUS
 * ----------
 * Purpose:
 *   Open-source systems monitoring and alerting toolkit.
 *   Collects and stores metrics as time series data from Pods and Nodes.
 *
 * Architecture & Behavior:
 *   - Server: Deployed as a Deployment (single replica by default in this chart) acting
 *     as the central metric collector.
 *   - Scraper: Uses a pull-based model, querying metrics endpoints (/metrics) on
 *     Pods and Services via Kubernetes Service Discovery.
 *   - Storage: Configured with a Persistent Volume Claim (PVC) to ensure metric durability
 *     across pod restarts.
 */

resource "helm_release" "prometheus" {
  name            = "prometheus"
  repository      = "https://prometheus-community.github.io/helm-charts"
  chart           = "prometheus"
  namespace       = kubernetes_namespace_v1.admin.metadata[0].name
  version         = "25.11.0"
  cleanup_on_fail = true

  values = [
    yamlencode({
      server = {
        retention = "15d"
        persistentVolume = {
          enabled      = true
          size         = "5Gi"
          storageClass = "gp3"
        }
      }
      alertmanager = {
        persistentVolume = {
          storageClass = "gp3"
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.admin,
    aws_eks_node_group.main,
    aws_eks_addon.coredns,
    helm_release.alb_controller
  ]
}

/*
 * -------
 * GRAFANA
 * -------
 * Purpose:
 *   Visualization and analytics platform.
 *   Configured to visualize metrics collected by the Prometheus server.
 *
 * Architecture & Behavior:
 *   - Deployment: Runs as a stateless Deployment.
 *   - Integration: Pre-configured via `datasources.yaml` to connect to the internal
 *     Prometheus service (`http://prometheus-server`) within the same namespace.
 *   - Access: Exposed via a LoadBalancer Service to provide a stable external endpoint.
 */

resource "helm_release" "grafana" {
  name            = "grafana"
  repository      = "https://grafana.github.io/helm-charts"
  chart           = "grafana"
  namespace       = kubernetes_namespace_v1.admin.metadata[0].name
  version         = "8.5.1"
  timeout         = 900 # Increase timeout to 15m to allow for LB provisioning
  cleanup_on_fail = true

  values = [
    yamlencode({
      service = {
        type = "LoadBalancer"
        annotations = {
          # Delegate to the installed AWS Load Balancer Controller
          "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
          "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
          "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
        }
      }
      # Increase probe timeouts to accommodate slower startup on t3.small nodes
      readinessProbe = {
        initialDelaySeconds = 60
        failureThreshold    = 10
      }
      livenessProbe = {
        initialDelaySeconds = 60
        failureThreshold    = 10
      }
      # Automatically configure Prometheus as the default data source
      datasources = {
        "datasources.yaml" = {
          apiVersion = 1
          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              url       = "http://prometheus-server"
              access    = "proxy"
              isDefault = true
            }
          ]
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.admin,
    helm_release.prometheus,
    aws_eks_node_group.main,
    aws_eks_addon.coredns
  ]
}
