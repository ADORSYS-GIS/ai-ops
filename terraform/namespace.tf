resource "kubernetes_namespace" "litellm_namespace" {
  metadata {
    name = local.namespace
  }
}

resource "kubernetes_namespace" "kubeai_namespace" {
  metadata {
    name = local.kubeai_namespace
  }
}

