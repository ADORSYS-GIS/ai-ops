locals {
  redis_node = module.redis.cluster_cache_nodes[0]
  redis_url  = "redis://${local.redis_node.address}:${local.redis_node.port}"
}

resource "kubernetes_secret" "litellm_redis_secret" {
  metadata {
    name      = "litellm-redis-secret"
    namespace = kubernetes_namespace.litellm_namespace.metadata[0].name
  }
  data = {
    REDIS_URL = local.redis_url
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_openai_api_key" {
  metadata {
    name      = "litellm-openai-api-key"
    namespace = kubernetes_namespace.litellm_namespace.metadata[0].name
  }
  data = {
    OPENAI_API_KEY = var.openai_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_fireworks_key" {
  metadata {
    name      = "litellm-fireworks-key"
    namespace = kubernetes_namespace.litellm_namespace.metadata[0].name
  }
  data = {
    FIREWORKS_AI_API_KEY = var.fireworks_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_gemini_api_key" {
  metadata {
    name      = "litellm-gemini-api-key"
    namespace = kubernetes_namespace.litellm_namespace.metadata[0].name
  }
  data = {
    GEMINI_API_KEY = var.gemini_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_anthropic_api_key" {
  metadata {
    name      = "litellm-anthropic-api-key"
    namespace = kubernetes_namespace.litellm_namespace.metadata[0].name
  }
  data = {
    ANTHROPIC_API_KEY = var.anthropic_key
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_secret" "litellm_master_key" {
  metadata {
    name      = "litellm-master-key"
    namespace = kubernetes_namespace.litellm_namespace.metadata[0].name
  }
  data = {
    master_key = var.litelllm_masterkey
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}


resource "kubernetes_secret" "open_web_ui_keys" {
  metadata {
    name      = "open-web-ui-keys"
    namespace = kubernetes_namespace.chat_ui_namespace.metadata[0].name
  }
  data = {
    openai-api-keys        = "${var.pipeline_key};${var.litelllm_masterkey}"
    litellm-openai-api-key = var.litelllm_masterkey
  }

  depends_on = [kubernetes_namespace.chat_ui_namespace]
}

resource "kubernetes_secret" "open_web_ui_oidc" {
  metadata {
    name      = "open-web-ui-oidc"
    namespace = kubernetes_namespace.chat_ui_namespace.metadata[0].name
  }
  data = {
    oauth_client_id     = var.oidc_kc_client_id
    oauth_client_secret = var.oidc_kc_client_secret
    openid_provider_url = "${var.oidc_kc_issuer_url}/.well-known/openid-configuration"
  }

  depends_on = [kubernetes_namespace.chat_ui_namespace]
}

resource "kubernetes_secret" "open_web_ui_s3" {
  metadata {
    name      = "open-web-ui-s3"
    namespace = kubernetes_namespace.chat_ui_namespace.metadata[0].name
  }
  data = {
    STORAGE_PROVIDER     = "s3"
    S3_BUCKET_NAME       = local.s3_bucket_name
    S3_REGION_NAME       = var.region
    S3_ACCESS_KEY_ID     = local.s3_access_key_id
    S3_SECRET_ACCESS_KEY = local.s3_secret_access_key
  }

  depends_on = [kubernetes_namespace.chat_ui_namespace]
}

resource "kubernetes_secret" "open_web_ui_config" {
  metadata {
    name      = "open-web-ui-config"
    namespace = kubernetes_namespace.chat_ui_namespace.metadata[0].name
  }
  data = {
    webui-secret-key     = var.webui_secret_key
    brave-search-api-key = var.brave_api_key
  }

  depends_on = [kubernetes_namespace.chat_ui_namespace]
}

resource "kubernetes_secret" "open_web_ui_redis_secret" {
  metadata {
    name      = "open-web-ui-redis-secret"
    namespace = kubernetes_namespace.chat_ui_namespace.metadata[0].name
  }
  data = {
    redis-url = local.redis_url
  }

  depends_on = [kubernetes_namespace.chat_ui_namespace]
}

resource "kubernetes_secret" "open_web_ui_tools" {
  metadata {
    name      = "open-web-ui-tools"
    namespace = kubernetes_namespace.chat_ui_namespace.metadata[0].name
  }
  data = {
    "tools.json" = templatefile("${path.module}/files/tools.json", {
      tool_api_key = var.tool_api_key,
    })
  }

  depends_on = [kubernetes_namespace.chat_ui_namespace]
}

resource "kubernetes_secret" "mcpo_env" {
  metadata {
    name      = "mcpo-api-key-env"
    namespace = kubernetes_namespace.mcpo_namespace.metadata[0].name
  }
  data = {
    API_KEY = var.tool_api_key
  }

  depends_on = [kubernetes_namespace.mcpo_namespace]
}

resource "kubernetes_secret" "mcpo_config" {
  metadata {
    name      = "mcpo-config-gen"
    namespace = kubernetes_namespace.mcpo_namespace.metadata[0].name
  }
  data = {
    "config.json" = templatefile("${path.module}/files/mcp-servers.json", {
      brave_api_key = var.brave_api_key,
    })
  }

  depends_on = [kubernetes_namespace.mcpo_namespace]
}