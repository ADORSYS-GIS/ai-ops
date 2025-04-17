variable "region" {
  description = "The AWS region to deploy resources to"
  type        = string
  default     = "eu-west-1"
}

variable "name" {
  description = "The name of the cluster"
  type        = string
  default     = "ai"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "11.0.0.0/16"
}

variable "azs" {
  description = "Availability Zones for the VPC"
  type        = list(string)
  default     = ["eu-west-1a", "eu-west-1b"]
}

variable "db_username" {
  description = "Username for the RDS database"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
}

variable "db_instance" {
  description = "The instance type for the RDS database"
  type        = string
  default     = "db.t3.medium"
}

variable "environment" {
  description = "The environment to deploy resources to"
  type        = string
  default     = "dev"
}

variable "eks_ec2_instance_types" {
  description = "The EC2 instance type for the EKS server"
  type        = list(string)
}

variable "eks_min_instance" {
  description = "The minimum number of instances for the EKS cluster"
  type        = number
  default     = 1
}

variable "eks_max_instance" {
  description = "The maximum number of instances for the EKS cluster"
  type        = number
  default     = 3
}

variable "eks_desired_instance" {
  description = "The desired number of instances for the EKS cluster"
  type        = number
  default     = 2
}

variable "db_backup_retention_period" {
  description = "The number of days to retain backups for"
  type        = number
  default     = null
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip the final snapshot when deleting the RDS database"
  type        = bool
  default     = true
}

variable "zone_name" {
  description = "The name of the Route 53 zone"
  type        = string
}

variable "cert_arn" {
  description = "The ARN of the SSL certificate"
  type        = string
}

variable "oidc_kc_client_id" {
  description = "The client ID for the OIDC provider"
  type        = string
  sensitive   = true
}

variable "oidc_kc_client_secret" {
  description = "The client secret for the OIDC provider"
  type        = string
  sensitive   = true
}

variable "oidc_kc_issuer_url" {
  description = "The issuer URL for the OIDC provider"
  type        = string
}

#======
variable "pipeline_key" {
  type        = string
  sensitive   = true
  description = "Pipeline Key"
}
variable "litelllm_masterkey" {
  type        = string
  sensitive   = true
  description = "LiteLLM Master Key"
}
variable "webui_secret_key" {
  type        = string
  sensitive   = true
  description = "WebUI Secret Key"
}
variable "brave_api_key" {
  type        = string
  sensitive   = true
  description = "Brave API Key"
}
variable "anthropic_key" {
  type        = string
  sensitive   = true
  description = "Anthropic API Key"
}
variable "gemini_key" {
  type        = string
  sensitive   = true
  description = "Gemini API Key"
}
variable "openapi_key" {
  type        = string
  sensitive   = true
  description = "OpenAI API Key"
}
variable "groq_api_key" {
  type        = string
  sensitive   = true
  description = "Groq API Key"
}
