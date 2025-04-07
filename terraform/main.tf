terraform {
  required_version = ">= 1.9.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

locals {
  name         = "adorsys-ai-${var.name}"
  azs_count = length(var.azs)
  azs          = var.azs
  argocdDomain = "${local.name}-argocd.${var.zone_name}"
  tags = {
    Owner       = local.name,
    Environment = var.environment
  }
}