locals {
  name         = "ai-${var.name}-cluster"
  azs          = var.azs
  argocdDomain = "${local.name}-argocd.${var.zone_name}"
  sg           = "${local.name}-sg"
  azs_count = length(var.azs)

  app_name  = "kivoyo"
  namespace = local.app_name
  
  tags = {
    Owner       = local.name,
    Environment = var.environment
  }
}