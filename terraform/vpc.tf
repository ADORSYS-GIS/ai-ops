module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${local.name}-vpc"
  cidr = var.vpc_cidr
  azs  = var.azs

  default_security_group_name = local.sg

  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 6, k)]
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 6, k + 2 * local.azs_count)]
  intra_subnets   = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 6, k + 13 * local.azs_count)]

  enable_vpn_gateway     = true
  enable_nat_gateway     = true
  single_nat_gateway     = true
  one_nat_gateway_per_az = false
  enable_dns_hostnames   = true
  enable_dns_support     = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1,
    "karpenter.sh/discovery"          = local.eks_name
  }

  tags = merge(
    local.tags,
    {
      "kubernetes.io/cluster/${local.eks_name}" = "shared"
    }
  )
}