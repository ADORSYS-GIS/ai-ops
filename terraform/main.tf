terraform {
  required_version = ">= 1.9.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

module "librechat" {
  source = "./modules/librechat"

  creds_secret           = "librechat-creds-env"
  litelllm_masterkey     = var.litelllm_masterkey
  s3_access_key_id       = module.storage.s3_access_key_id
  s3_secret_access_key   = module.storage.s3_secret_access_key
  s3_region              = module.storage.s3_region
  s3_bucket_name         = module.storage.s3_bucket_name
  keycloak_client_id     = var.librechat_client_id
  keycloak_client_secret = var.librechat_client_secret
  redis_uri              = module.cache.redis_url
  tags                   = local.tags
}

module "storage" {
  source = "./modules/storage"

  allowed_origin = "https://${var.zone_name}"
  tags           = local.tags
  region         = var.region
  bucket_name    = "${var.name}-${var.environment}-web"
}

module "cache" {
  source = "./modules/cache"

  name       = local.name
  tags       = local.tags
  vpc_id     = module.vpc.vpc_id
  cidr_ipv4  = module.vpc.vpc_cidr_block
  subnet_ids = module.vpc.private_subnets
}
