resource "kubernetes_namespace" "litellm_namespace" {
  metadata {
    name = "litellm"
  }
}

resource "kubernetes_namespace" "chat_ui_namespace" {
  metadata {
    name = "chat-ui"
  }
}

resource "kubernetes_namespace" "mcpo_namespace" {
  metadata {
    name = "mcpo"
  }
}

resource "kubernetes_namespace" "envoy_gateway_system" {
  metadata {
    name = "envoy-gateway-system"
  }
}
