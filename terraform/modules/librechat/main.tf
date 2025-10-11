resource "random_string" "meilisearch_secret" {
  length = 32
}

resource "random_string" "social_session_secret" {
  length = 32
}

# 32 bytes -> 64 hex chars (openssl rand -hex 32)
resource "random_id" "creds_key" {
  byte_length = 32
}

# 16 bytes -> 32 hex chars (openssl rand -hex 16)
resource "random_id" "creds_iv" {
  byte_length = 16
}

# 32 bytes -> 64 hex chars (good JWT secret length)
resource "random_id" "jwt_secret" {
  byte_length = 32
}

# 32 bytes -> 64 hex chars (good JWT refresh secret length)
resource "random_id" "jwt_refresh_secret" {
  byte_length = 32
}

resource "kubernetes_namespace" "ns" {
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_secret" "creds-secret" {
  metadata {
    name      = local.creds-secret
    namespace = kubernetes_namespace.ns.metadata[0].name
  }
  data = {
    MEILI_MASTER_KEY   = local.meili-master-key
    CREDS_KEY          = random_id.creds_key.hex
    CREDS_IV           = random_id.creds_iv.hex
    JWT_SECRET         = random_id.jwt_secret.hex
    JWT_REFRESH_SECRET = random_id.jwt_refresh_secret.hex

    KIVOYO_OPENAI_API_KEY = var.litelllm_masterkey

    AWS_ACCESS_KEY_ID     = var.s3_access_key_id
    AWS_SECRET_ACCESS_KEY = var.s3_secret_access_key
    AWS_REGION            = var.s3_region
    AWS_BUCKET_NAME       = var.s3_bucket_name
    #AWS_ENDPOINT_URL      = your_endpoint_url

    OPENID_CLIENT_ID      = var.keycloak_client_id
    OPENID_CLIENT_SECRET  = var.keycloak_client_secret
    OPENID_SESSION_SECRET = random_string.social_session_secret.result

    # USE_REDIS = "true"
    REDIS_URI = var.redis_uri
  }

  depends_on = [kubernetes_namespace.ns]
}
