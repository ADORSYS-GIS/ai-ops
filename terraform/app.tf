module "ops" {
  source  = "blackbird-cloud/deployment/helm"
  version = "~> 1.0"

  name             = "ops"
  namespace        = "argocd"
  create_namespace = false

  repository    = "https://bedag.github.io/helm-charts"
  chart         = "raw"
  chart_version = "2.0.0"

  values = [
    templatefile("${path.module}/files/argo-cd-apps.yaml", {
      environment    = var.environment
      fileSystemId   = module.efs.id
      cluster_name   = local.eks_name
      karpenter_role = module.eks.eks_managed_node_groups["knative-ng"].iam_role_name
    })
  ]

  cleanup_on_fail = true
  wait            = true
}