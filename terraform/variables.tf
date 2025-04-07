variable "region" {
  description = "The AWS region to deploy resources to"
  type        = string
  default     = "eu-west-1"
}

variable "name" {
  description = "The name of the cluster"
  type        = string
  default     = "ai-cluster"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "12.34.0.0/16"
}

variable "azs" {
  description = "Availability Zones for the VPC"
  type = list(string)
  default = ["eu-west-1a", "eu-west-1b"]
}

variable "db_username" {
  description = "Username for the RDS database"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
  sensitive   = true
}

variable "prs_private_key" {
  description = "prs private key token"
  type        = string
  sensitive   = true
}

variable "prs_public_key" {
  description = "prs public key token"
  type        = string
  sensitive   = false
}

variable "jwt_issuer" {
  description = "jwt issuer"
  type        = string
  sensitive   = false
}

variable "jwt_expiration" {
  description = "jwt expiration"
  type        = string
  sensitive   = false
}

variable "twilio_account_sid" {
  description = "twilio account sid"
  type        = string
  sensitive   = false
}

variable "twilio_auth_token" {
  description = "twilio auth token"
  type        = string
  sensitive   = false
}

variable "twilio_phone_number" {
  description = "twilio phone number"
  type        = string
  sensitive   = false
}

variable "otp_salt" {
  description = "otp salt"
  type        = string
  sensitive   = true
}

variable "email" {
  description = "email"
  type        = string
  sensitive   = false
}

variable "email_password" {
  description = "email password"
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
  description = "The EC2 instance type for the Jenkins server"
  type = list(string)
  default = ["t2.medium"]
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

variable "eks_gpu_ec2_instance_types" {
  description = "The EC2 instance type for the Jenkins server"
  type = list(string)
  default = ["t2.medium"]
}

variable "eks_gpu_min_instance" {
  description = "The minimum number of instances for the EKS GPU cluster"
  type        = number
  default     = 1
}

variable "eks_gpu_max_instance" {
  description = "The maximum number of instances for the EKS GPU cluster"
  type        = number
  default     = 2
}

variable "eks_gpu_desired_instance" {
  description = "The desired number of instances for the EKS GPU cluster"
  type        = number
  default     = 1
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
  default     = "apple.banana.miaou"
}

variable "cert_arn" {
  description = "The ARN of the SSL certificate"
  type        = string
}

variable "oidc_kc_client_id" {
  description = "The client ID for the OIDC provider"
  type        = string
}

variable "oidc_kc_client_secret" {
  description = "The client secret for the OIDC provider"
  type        = string
}

variable "oidc_kc_issuer_url" {
  description = "The issuer URL for the OIDC provider"
  type        = string
}

variable "userapp_teller_password" {
  description = "Password for teller privileges in userapp"
  type        = string
  sensitive   = true
}

#======
variable "litelllm_masterkey" {
  type        = string
  sensitive   = true
  description = "Meh" # TODO
}
variable "anthropic_key" {
  type        = string
  sensitive   = true
  description = "Meh" # TODO
}
variable "gemini_key" {
  type        = string
  sensitive   = true
  description = "Meh" # TODO
}
variable "openapi_key" {
  type        = string
  sensitive   = true
  description = "Meh" # TODO
}