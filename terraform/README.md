# EKS Terraform Setup

This Terraform configuration creates a basic AWS EKS cluster with the following resources:

- VPC with 3 availability zones and 3 private subnets
- EKS cluster with a node group (t3.medium instances)
- Outputs the `kubeconfig` for interacting with the EKS cluster

## Steps to Run

0. Create args for your tf command:
   ```shell
   export TF_VAR_cert_arn="arn:aws:acm:eu-central-1:571075516563:certificate/38142a7c-8878-457a-94ac-6994193e8e05"
   export TF_VAR_oidc_kc_client_id="ai-argocd-dev"
   export TF_VAR_oidc_kc_client_secret="6nKSCC73JxOhkxlAy6eLQvQleWZeaTIW"
   export TF_VAR_oidc_kc_issuer_url="https://accounts.ssegning.com/realms/konk"
   export TF_VAR_zone_name="kivoyo.com"
   export TF_VAR_db_username="db_username"
   export TF_VAR_db_password="db_username_password123"
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