locals {
  name         = "kivoyo-${var.name}-cluster"
  eks_name     = "${local.name}-eks"
  azs          = var.azs
  argocdDomain = "${local.name}-argocd.${var.zone_name}"
  sg           = "${local.name}-sg"
  azs_count = length(var.azs)
  
  tags = {
    Owner       = local.name,
    Environment = var.environment
  }
}