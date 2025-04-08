module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = "${local.name}-eks"
  cluster_endpoint_public_access = true
  enable_efa_support             = true
  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  control_plane_subnet_ids       = module.vpc.intra_subnets
  create_cloudwatch_log_group    = false

  eks_managed_node_groups = {
    cluster-ng = {
      name           = "main"
      min_size       = var.eks_min_instance
      max_size       = var.eks_max_instance
      desired_size   = var.eks_desired_instance
      instance_types = var.eks_ec2_instance_types
      capacity_type  = "SPOT"
    }
    gpu-cluster-ng = {
      name           = "accel"
      ami_type       = "AL2_x86_64_GPU"
      min_size       = var.eks_gpu_min_instance
      max_size       = var.eks_gpu_max_instance
      desired_size   = var.eks_gpu_desired_instance
      instance_types = var.eks_gpu_ec2_instance_types
      capacity_type  = "SPOT"
      labels = {
        gpu-node : "yes"
      }
      taints = [
        {
          key    = "gpu-node"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
    }
  }

  enable_cluster_creator_admin_permissions = true

  tags = merge(
    local.tags,
    {
      "kubernetes.io/cluster/${local.name}-eks" = "shared",
      "kubernetes.io/cluster-service"           = "true"
    }
  )
}

module "eks_blueprints_addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  depends_on = [module.eks]

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    coredns = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    kube-proxy = {
      most_recent = true
    }
  }

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    set = [
      {
        name  = "vpcId"
        value = module.vpc.vpc_id
      },
      {
        name  = "enableServiceMutatorWebhook"
        value = "false"
      },
      {
        name  = "podDisruptionBudget.maxUnavailable"
        value = 1
      },
      {
        name  = "resources.requests.cpu"
        value = "100m"
      },
      {
        name  = "resources.requests.memory"
        value = "128Mi"
      },
    ]
  }

  enable_external_dns = true
  external_dns_route53_zone_arns = [data.aws_route53_zone.selected.arn]
  external_dns = {
    name          = "external-dns"
    chart_version = "1.16.0"
    repository    = "https://kubernetes-sigs.github.io/external-dns/"
    namespace     = "external-dns"
    values = [templatefile("${path.module}/files/externaldns-values.yaml", {})]
  }

  enable_cluster_autoscaler = true
  cluster_autoscaler = {
    name          = "cluster-autoscaler"
    chart_version = "9.46.6"
    repository    = "https://kubernetes.github.io/autoscaler"
    namespace     = "kube-system"
    values = [templatefile("${path.module}/files/autoscaler-values.yaml", {})]
  }

  enable_argocd = true
  argocd = {
    name          = "argocd"
    chart_version = "7.8.23"
    repository    = "https://argoproj.github.io/argo-helm"
    namespace     = "argocd"
    values = [
      templatefile("${path.module}/files/argocd-values.yaml", {
        domain                = local.argocdDomain,
        name                  = local.name,
        certArn               = var.cert_arn,
        oidc_kc_client_id     = var.oidc_kc_client_id,
        oidc_kc_client_secret = var.oidc_kc_client_secret,
        oidc_kc_issuer_url    = var.oidc_kc_issuer_url,
      })
    ]
  }

  tags = merge(
    local.tags,
    {
      "kubernetes.io/cluster/${local.name}-eks" = "shared"
    }
  )
}