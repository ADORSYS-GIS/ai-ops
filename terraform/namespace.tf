resource "kubernetes_namespace" "litellm_namespace" {
  metadata {
    name = local.namespace
  }
}

