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

resource "kubernetes_secret" "litellm_fireworks_api_key" {
  metadata {
    name      = "litellm-fireworks-api-key"
    namespace = local.namespace
  }
  data = {
    FIREWORKS_AI_API_KEY = var.fireworks_ai_api_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_deepgram_api_key" {
  metadata {
    name      = "litellm-deepgram-api-key"
    namespace = local.namespace
  }
  data = {
    DEEPGRAM_API_KEY = var.deepgram_api_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_deepseek_api_key" {
  metadata {
    name      = "litellm-deepseek-api-key"
    namespace = local.namespace
  }
  data = {
    DEEPSEEK_API_KEY = var.deepseek_api_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_togetherai_api_key" {
  metadata {
    name      = "litellm-togetherai-api-key"
    namespace = local.namespace
  }
  data = {
    TOGETHERAI_API_KEY = var.togetherai_api_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_voyage_api_key" {
  metadata {
    name      = "litellm-voyage-api-key"
    namespace = local.namespace
  }
  data = {
    VOYAGE_API_KEY = var.voyage_api_key
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

resource "kubernetes_secret" "litellm_groq_api_key" {
  metadata {
    name      = "litellm-groq-api-key"
    namespace = local.namespace
  }
  data = {
    GROQ_API_KEY = var.groq_api_key
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
    OPENAI_API_KEYS          = "${var.pipeline_key};${var.litelllm_masterkey}"
    AUDIO_STT_OPENAI_API_KEY = var.litelllm_masterkey
    AUDIO_TTS_OPENAI_API_KEY = var.litelllm_masterkey
    IMAGES_OPENAI_API_KEY    = var.litelllm_masterkey
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
    DATABASE_URL       = "postgresql://${var.db_username}:${var.db_password}@${module.rds.db_instance_endpoint}/${module.rds.db_instance_name}_web_ui"
    DATABASE_POOL_SIZE = "10"
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "open_web_ui_db_init" {
  metadata {
    name      = "open-web-ui-db-init"
    namespace = local.namespace
  }
  data = {
    PGDATABASE   = module.rds.db_instance_name
    PGHOST       = local.db_host
    PGPORT       = module.rds.db_instance_port
    PGUSER       = var.db_username
    PGPASSWORD   = var.db_password
    DB_TO_CREATE = "${module.rds.db_instance_name}_web_ui"
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "open_web_ui_config" {
  metadata {
    name      = "open-web-ui-config"
    namespace = local.namespace
  }
  data = {
    WEBUI_SECRET_KEY     = var.webui_secret_key
    BRAVE_SEARCH_API_KEY = var.brave_api_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}
