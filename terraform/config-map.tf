resource "kubernetes_config_map" "litellm_db_config" {
  metadata {
    name      = "litellm-rds-config"
    namespace = "kivoyo"
  }
  data = {
    DATABASE_URL = "postgresql://$(DATABASE_USERNAME):$(DATABASE_PASSWORD)@$(DATABASE_HOST)/$(DATABASE_NAME)"
  }
}