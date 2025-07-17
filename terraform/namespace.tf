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
