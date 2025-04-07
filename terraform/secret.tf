resource "kubernetes_secret" "litellm_rds_secret" {
  metadata {
    name      = "litellm-rds-secret"
    namespace = "kivoyo"
  }
  data = {
    DATABASE_USERNAME = var.db_username
    DATABASE_PASSWORD = var.db_password
    DATABASE_HOST = "" #TODO
    DATABASE_NAME     = "" #TODO
  }
}

locals {
  redis_url = "redis://redis-master.database.svc.cluster.local:6379"
}

resource "kubernetes_secret" "litellm_redis_secret" {
  metadata {
    name      = "litellm-redis-secret"
    namespace = "kivoyo"
  }
  data = {
    REDIS_URL           = local.redis_url
    WEBSOCKET_REDIS_URL = local.redis_url
  }
}

resource "kubernetes_secret" "litellm_openai_api_key" {
  metadata {
    name      = "litellm-openai-api-key"
    namespace = "kivoyo"
  }
  data = {
    OPENAI_API_KEY = var.openapi_key
  }
}

resource "kubernetes_secret" "litellm_gemini_api_key" {
  metadata {
    name      = "litellm-gemini-api-key"
    namespace = "kivoyo"
  }
  data = {
    GEMINI_API_KEY = var.gemini_key
  }
}

resource "kubernetes_secret" "litellm_anthropic_api_key" {
  metadata {
    name      = "litellm-anthropic-api-key"
    namespace = "kivoyo"
  }
  data = {
    ANTHROPIC_API_KEY = var.anthropic_key
  }
}

resource "kubernetes_secret" "litellm_master_key" {
  metadata {
    name      = "litellm-master-key"
    namespace = "kivoyo"
  }
  data = {
    masterkey = var.litelllm_masterkey
  }
}
