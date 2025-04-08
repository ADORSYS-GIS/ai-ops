output "argocd_server_url" {
  value = "https://${local.argocdDomain}"
}