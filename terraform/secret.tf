resource "kubernetes_secret" "litellm_rds_secret" {
  metadata {
    name      = "litellm-rds-secret"
    namespace = local.namespace
  }
  data = {
    DATABASE_USERNAME = var.db_username
    DATABASE_PASSWORD = var.db_password
    DATABASE_HOST     = module.rds.db_instance_endpoint
    DATABASE_NAME     = module.rds.db_instance_name
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

locals {
  redis_node = module.redis.cluster_cache_nodes[0]
  redis_url  = "redis://${local.redis_node.address}:${local.redis_node.port}"
}

resource "kubernetes_secret" "litellm_redis_secret" {
  metadata {
    name      = "litellm-redis-secret"
    namespace = local.namespace
  }
  data = {
    REDIS_URL           = local.redis_url
    WEBSOCKET_REDIS_URL = local.redis_url
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_openai_api_key" {
  metadata {
    name      = "litellm-openai-api-key"
    namespace = local.namespace
  }
  data = {
    OPENAI_API_KEY = var.openapi_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_gemini_api_key" {
  metadata {
    name      = "litellm-gemini-api-key"
    namespace = local.namespace
  }
  data = {
    GEMINI_API_KEY = var.gemini_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_anthropic_api_key" {
  metadata {
    name      = "litellm-anthropic-api-key"
    namespace = local.namespace
  }
  data = {
    ANTHROPIC_API_KEY = var.anthropic_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_master_key" {
  metadata {
    name      = "litellm-master-key"
    namespace = local.namespace
  }
  data = {
    master_key = var.litelllm_masterkey
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "open_web_ui_keys" {
  metadata {
    name      = "open-web-ui-keys"
    namespace = local.namespace
  }
  data = {
    keys = "${var.pipeline_key};${var.litelllm_masterkey}"
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "open_web_ui_oidc" {
  metadata {
    name      = "open-web-ui-oidc"
    namespace = local.namespace
  }
  data = {
    oauth_client_id     = var.oidc_kc_client_id
    oauth_client_secret = var.oidc_kc_client_secret
    openid_provider_url = "${var.oidc_kc_issuer_url}/.well-known/openid-configuration"
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "open_web_ui_s3" {
  metadata {
    name      = "open-web-ui-s3"
    namespace = local.namespace
  }
  data = {
    S3_BUCKET_NAME       = local.s3_bucket_name
    S3_REGION_NAME       = var.region
    S3_ACCESS_KEY_ID     = local.s3_access_key_id
    S3_SECRET_ACCESS_KEY = local.s3_secret_access_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "open_web_ui_db" {
  metadata {
    name      = "open-web-ui-db"
    namespace = local.namespace
  }
  data = {
    DATABASE_URL       = "postgresql://${var.db_username}:${var.db_password}@${module.rds.db_instance_endpoint}/${module.rds.db_instance_name}?schema=${local.db_open_web_ui}"
    DATABASE_POOL_SIZE = "10"
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}
