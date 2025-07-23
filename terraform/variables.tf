variable "region" {
  description = "The AWS region to deploy resources to"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_version" {
  description = "The version of the cluster"
  type        = string
  default     = "1.32"
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
  type = list(string)
  default = ["eu-west-1a", "eu-west-1b"]
}

variable "environment" {
  description = "The environment to deploy resources to"
  type        = string
  default     = "dev"
}

variable "cpu_ec2_instance_types" {
  description = "The EC2 instance type for the CPU server"
  type = list(string)
}

variable "cpu_min_instance" {
  description = "The minimum number of instances for the CPU cluster"
  type        = number
  default     = 0
}

variable "cpu_max_instance" {
  description = "The maximum number of instances for the CPU cluster"
  type        = number
  default     = 2
}

variable "cpu_desired_instance" {
  description = "The desired number of instances for the CPU cluster"
  type        = number
  default     = 0
}

variable "cpu_capacity_type" {
  default     = "SPOT"
  description = "MLFlow EC2 Capacity type"
}

variable "mlflow_ec2_instance_types" {
  description = "The EC2 instance type for the MLFlow server"
  type = list(string)
}

variable "mlflow_min_instance" {
  description = "The minimum number of instances for the MLFlow cluster"
  type        = number
  default     = 0
}

variable "mlflow_max_instance" {
  description = "The maximum number of instances for the MLFlow cluster"
  type        = number
  default     = 2
}

variable "mlflow_desired_instance" {
  description = "The desired number of instances for the MLFlow cluster"
  type        = number
  default     = 0
}

variable "mlflow_capacity_type" {
  default     = "ON_DEMAND"
  description = "MLFlow EC2 Capacity type"
}

variable "knative_ec2_instance_types" {
  description = "The EC2 instance type for the Knative server"
  type = list(string)
}

variable "knative_min_instance" {
  description = "The minimum number of instances for the Knative cluster"
  type        = number
  default     = 0
}

variable "knative_max_instance" {
  description = "The maximum number of instances for the Knative cluster"
  type        = number
  default     = 2
}

variable "knative_desired_instance" {
  description = "The desired number of instances for the Knative cluster"
  type        = number
  default     = 0
}

variable "knative_capacity_type" {
  default     = "ON_DEMAND"
  description = "Knative EC2 Capacity type"
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

variable "tool_api_key" {
  type        = string
  sensitive   = true
  description = "Tool API Key"
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

variable "openai_key" {
  type        = string
  sensitive   = true
  description = "OpenAI API Key"
}

variable "fireworks_key" {
  type        = string
  sensitive   = true
  description = "Firework Key"
}
