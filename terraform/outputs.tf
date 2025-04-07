output "eks_cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "The endpoint URL of the EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "argocd_server_url" {
  value = "https://${local.argocdDomain}"
}

output "rds_database_name" {
  value = module.rds.db_instance_name
}

output "rds_url" {
  value = module.rds.db_instance_endpoint
}