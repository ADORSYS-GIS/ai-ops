variable "namespace" {
  type        = string
  default     = ""
  description = "Namespace's name for librechat"
}

variable "creds_secret" {
  type        = string
  default     = ""
  description = "Name of the Creds Secret"
}

variable "meili_master_key" {
  type        = string
  default     = ""
  description = "Name of the Creds Secret"
}

variable "litelllm_masterkey" {
  type        = string
  sensitive   = true
  description = "LiteLLM API Key"
}

variable "s3_access_key_id" {
  type      = string
  sensitive = true
}

variable "s3_secret_access_key" {
  type      = string
  sensitive = true
}

variable "s3_region" {
  type = string
}

variable "s3_bucket_name" {
  type = string
}

variable "keycloak_client_id" {
  type      = string
  sensitive = true
}

variable "keycloak_client_secret" {
  type      = string
  sensitive = true
}

variable "redis_uri" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
}

