module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                             = "${local.name}-eks"
  cluster_endpoint_public_access           = true
  enable_efa_support                       = true
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  control_plane_subnet_ids                 = module.vpc.intra_subnets
  create_cloudwatch_log_group              = false
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    cpu-ng = {
      name           = "cpu"
      min_size       = var.eks_min_instance
      max_size       = var.eks_max_instance
      desired_size   = var.eks_desired_instance
      instance_types = var.eks_ec2_instance_types
      capacity_type  = var.capacity_type

      iam_role_additional_policies = {
        ebs = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
      labels = {
        cpu-node : "true"
      }
      tags = merge(
        local.tags,
        {
          "cpu-node" = "true",
        }
      )
    }
    mlflow-ng = {
      name           = "mlflow-gpus"
      ami_type       = "BOTTLEROCKET_x86_64_NVIDIA"
      min_size       = var.eks_gpu_min_instance
      max_size       = var.eks_gpu_max_instance
      desired_size   = var.eks_gpu_desired_instance
      instance_types = var.eks_gpu_ec2_instance_types
      capacity_type  = var.capacity_type
      iam_role_additional_policies = {
        ebs = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
      labels = {
        gpu-node : "true"
        mflow-node : "true"
      }
      taints = [
        {
          key    = "mflow-node"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
      tags = merge(
        local.tags,
        {
          "gpu-node"   = "true",
          "mflow-node" = "true",
        }
      )
    }
    ollama-ng = {
      name           = "ollama-gpus"
      ami_type       = "BOTTLEROCKET_x86_64_NVIDIA"
      min_size       = var.eks_gpu_min_instance
      max_size       = var.eks_gpu_max_instance
      desired_size   = var.eks_gpu_desired_instance
      instance_types = var.eks_gpu_ec2_instance_types
      capacity_type  = var.capacity_type
      iam_role_additional_policies = {
        ebs = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
      labels = {
        gpu-node : "true"
        ollama-node : "true"
      }
      taints = [
        {
          key    = "ollama-node"
          value  = "true"
          effect = "NO_SCHEDULE"
        }
      ]
      tags = merge(
        local.tags,
        {
          "gpu-node"    = "true",
          "ollama-node" = "true",
        }
      )
    }
  }

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

  enable_argocd                       = true
  enable_external_dns                 = true
  enable_cluster_autoscaler           = true
  enable_aws_load_balancer_controller = true
  enable_aws_efs_csi_driver           = true

  eks_addons = {
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
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

  argocd = {
    name          = "argocd"
    chart_version = "7.8.19"
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

  external_dns_route53_zone_arns = [data.aws_route53_zone.selected.arn]

  tags = merge(
    local.tags,
    {
      "kubernetes.io/cluster/${local.name}-eks" = "shared"
      "kubernetes.io/cluster-service"           = "true"
    }
  )
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix = "${local.name}-ebs-csi-driver-"

  oidc_providers = {
    cluster = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  attach_ebs_csi_policy = true

  tags = merge(local.tags, {})
}
