locals {
  namespace        = coalesce(var.namespace, "librechat")
  creds-secret     = coalesce(var.creds_secret, "${local.namespace}-creds-env")
  meili-master-key = coalesce(var.meili_master_key, random_string.meilisearch_secret.result)
  tags             = merge({}, var.tags)
}
