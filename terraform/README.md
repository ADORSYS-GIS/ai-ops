# EKS Terraform Setup

This Terraform configuration creates a basic AWS EKS cluster with the following resources:

- VPC with 3 availability zones and 3 private subnets
- EKS cluster with a node group (t3.medium instances)
- Outputs the `kubeconfig` for interacting with the EKS cluster

## Steps to Run

0. Create args for your tf command:
   ```shell
   export TF_VAR_cert_arn="arn:aws:acm:eu-central-1:571075516563:certificate/..."
   export TF_VAR_oidc_kc_client_id="ai-argocd-dev"
   export TF_VAR_oidc_kc_client_secret="6nKSCC73JxOhkxlAy6eLQvQleWZeaTIW"
   export TF_VAR_oidc_kc_issuer_url="https://accounts.ssegning.com/realms/konk"
   export TF_VAR_zone_name="kivoyo.com"
   export TF_VAR_name="ai-test-me"
   export TF_VAR_region="eu-central-1"
   ```

1. Initialize Terraform:
   ```shell
   terraform init
   ```

2. Plan the Terraform configuration:
   ```shell
   terraform plan
   ```

3. Apply the configuration:
   ```shell
   terraform apply
   ```

4. Use `kubectl` to interact with the cluster.

## Check the terraform using tfsec and tflint

```shell
tfsec .
tflint
```

To use those, you should install them first. You can install them using the following commands:

```shell
brew install tfsec
brew install tflint
```

on macos or

```shell
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
```

on linux.

## Destroy the resources
To destroy the resources created by Terraform, run the following command:

```shell
terraform destroy
```
This will remove all the resources created by the Terraform configuration. Make sure to review the resources that will be destroyed before confirming.

## Configuration
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.8 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.100.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | 2.37.1 |
| <a name="provider_random"></a> [random](#provider\_random) | 3.7.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ebs_csi_driver_irsa"></a> [ebs\_csi\_driver\_irsa](#module\_ebs\_csi\_driver\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | n/a |
| <a name="module_efs"></a> [efs](#module\_efs) | terraform-aws-modules/efs/aws | n/a |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | ~> 20.0 |
| <a name="module_eks_blueprints_addons"></a> [eks\_blueprints\_addons](#module\_eks\_blueprints\_addons) | aws-ia/eks-blueprints-addons/aws | n/a |
| <a name="module_eks_data_addons"></a> [eks\_data\_addons](#module\_eks\_data\_addons) | aws-ia/eks-data-addons/aws | n/a |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | n/a |
| <a name="module_karpenter-helm"></a> [karpenter-helm](#module\_karpenter-helm) | blackbird-cloud/deployment/helm | ~> 1.0 |
| <a name="module_kms"></a> [kms](#module\_kms) | terraform-aws-modules/kms/aws | ~> 1.0 |
| <a name="module_ops"></a> [ops](#module\_ops) | blackbird-cloud/deployment/helm | ~> 1.0 |
| <a name="module_redis"></a> [redis](#module\_redis) | terraform-aws-modules/elasticache/aws | ~> 1.0 |
| <a name="module_s3_bucket"></a> [s3\_bucket](#module\_s3\_bucket) | terraform-aws-modules/s3-bucket/aws | ~> 4.0 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | ~> 5.0 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_access_key.s3_user_access_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_access_key) | resource |
| [aws_iam_user.s3_user](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_user) | resource |
| [kubernetes_namespace.chat_ui_namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_namespace.litellm_namespace](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace) | resource |
| [kubernetes_secret.litellm_anthropic_api_key](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.litellm_gemini_api_key](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.litellm_master_key](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.litellm_openai_api_key](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.litellm_redis_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.open_web_ui_config](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.open_web_ui_keys](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.open_web_ui_oidc](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.open_web_ui_redis_secret](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [kubernetes_secret.open_web_ui_s3](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [random_id.suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [aws_eks_cluster_auth.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_route53_zone.selected](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_anthropic_key"></a> [anthropic\_key](#input\_anthropic\_key) | Anthropic API Key | `string` | n/a | yes |
| <a name="input_azs"></a> [azs](#input\_azs) | Availability Zones for the VPC | `list(string)` | <pre>[<br/>  "eu-west-1a",<br/>  "eu-west-1b"<br/>]</pre> | no |
| <a name="input_brave_api_key"></a> [brave\_api\_key](#input\_brave\_api\_key) | Brave API Key | `string` | n/a | yes |
| <a name="input_capacity_type"></a> [capacity\_type](#input\_capacity\_type) | EC2 Capacity type | `any` | `null` | no |
| <a name="input_cert_arn"></a> [cert\_arn](#input\_cert\_arn) | The ARN of the SSL certificate | `string` | n/a | yes |
| <a name="input_db_backup_retention_period"></a> [db\_backup\_retention\_period](#input\_db\_backup\_retention\_period) | The number of days to retain backups for | `number` | `null` | no |
| <a name="input_eks_desired_instance"></a> [eks\_desired\_instance](#input\_eks\_desired\_instance) | The desired number of instances for the EKS cluster | `number` | `2` | no |
| <a name="input_eks_ec2_instance_types"></a> [eks\_ec2\_instance\_types](#input\_eks\_ec2\_instance\_types) | The EC2 instance type for the EKS server | `list(string)` | n/a | yes |
| <a name="input_eks_gpu_desired_instance"></a> [eks\_gpu\_desired\_instance](#input\_eks\_gpu\_desired\_instance) | The desired number of instances for the EKS GPU cluster | `number` | `0` | no |
| <a name="input_eks_gpu_ec2_instance_types"></a> [eks\_gpu\_ec2\_instance\_types](#input\_eks\_gpu\_ec2\_instance\_types) | The EC2 instance type for the EKS GPU server | `list(string)` | n/a | yes |
| <a name="input_eks_gpu_max_instance"></a> [eks\_gpu\_max\_instance](#input\_eks\_gpu\_max\_instance) | The maximum number of instances for the EKS GPU cluster | `number` | `2` | no |
| <a name="input_eks_gpu_min_instance"></a> [eks\_gpu\_min\_instance](#input\_eks\_gpu\_min\_instance) | The minimum number of instances for the EKS GPU cluster | `number` | `0` | no |
| <a name="input_eks_max_instance"></a> [eks\_max\_instance](#input\_eks\_max\_instance) | The maximum number of instances for the EKS cluster | `number` | `3` | no |
| <a name="input_eks_min_instance"></a> [eks\_min\_instance](#input\_eks\_min\_instance) | The minimum number of instances for the EKS cluster | `number` | `1` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | The environment to deploy resources to | `string` | `"dev"` | no |
| <a name="input_gemini_key"></a> [gemini\_key](#input\_gemini\_key) | Gemini API Key | `string` | n/a | yes |
| <a name="input_litelllm_masterkey"></a> [litelllm\_masterkey](#input\_litelllm\_masterkey) | LiteLLM Master Key | `string` | n/a | yes |
| <a name="input_name"></a> [name](#input\_name) | The name of the cluster | `string` | `"ai"` | no |
| <a name="input_oidc_kc_client_id"></a> [oidc\_kc\_client\_id](#input\_oidc\_kc\_client\_id) | The client ID for the OIDC provider | `string` | n/a | yes |
| <a name="input_oidc_kc_client_secret"></a> [oidc\_kc\_client\_secret](#input\_oidc\_kc\_client\_secret) | The client secret for the OIDC provider | `string` | n/a | yes |
| <a name="input_oidc_kc_issuer_url"></a> [oidc\_kc\_issuer\_url](#input\_oidc\_kc\_issuer\_url) | The issuer URL for the OIDC provider | `string` | n/a | yes |
| <a name="input_openapi_key"></a> [openapi\_key](#input\_openapi\_key) | OpenAI API Key | `string` | n/a | yes |
| <a name="input_pipeline_key"></a> [pipeline\_key](#input\_pipeline\_key) | Pipeline Key | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | The AWS region to deploy resources to | `string` | `"eu-west-1"` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | The CIDR block for the VPC | `string` | `"11.0.0.0/16"` | no |
| <a name="input_webui_secret_key"></a> [webui\_secret\_key](#input\_webui\_secret\_key) | WebUI Secret Key | `string` | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | The name of the Route 53 zone | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_argocd_server_url"></a> [argocd\_server\_url](#output\_argocd\_server\_url) | n/a |
<!-- END_TF_DOCS -->