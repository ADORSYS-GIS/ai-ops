resource "kubernetes_config_map" "litellm_db_config" {
  metadata {
    name      = "litellm-db-config"
    namespace = local.namespace
  }
  data = {
    DATABASE_URL = "postgresql://$(DATABASE_USERNAME):$(DATABASE_PASSWORD)@$(DATABASE_HOST)/$(DATABASE_NAME)"
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}

resource "kubernetes_config_map" "open_web_ui_s3" {
  metadata {
    name      = "open-web-ui-s3"
    namespace = local.namespace
  }
  data = {
    STORAGE_PROVIDER = "s3"
  }

  depends_on = [kubernetes_namespace.litellm_namespace]
}
