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
      environment  = var.environment
      fileSystemId = var.fileSystemId
    })
  ]

  cleanup_on_fail = true
  wait            = true
}