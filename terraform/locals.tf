locals {
  name         = "ai-${var.name}-cluster"
  eks_name     = "${local.name}-eks"
  azs          = var.azs
  argocdDomain = "${local.name}-argocd.${var.zone_name}"
  sg           = "${local.name}-sg"
  karpenter_sg = "karpenter_sg-${local.sg}"
  azs_count = length(var.azs)

  app_name         = "kivoyo"
  namespace        = local.app_name
  kubeai_namespace = var.kubeai_ns

  db_name = replace(local.name, "-", "_")

  tags = {
    Owner       = local.name,
    Environment = var.environment
  }
}