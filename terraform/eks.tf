module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_version                          = var.cluster_version
  cluster_name                             = "${local.name}-eks"
  cluster_endpoint_public_access           = false
  cluster_endpoint_private_access          = true
  enable_efa_support                       = true
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  control_plane_subnet_ids                 = module.vpc.intra_subnets
  create_cloudwatch_log_group              = false
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    cpu-ng = {
      use_custom_launch_template = false
      
      name           = "cpu"
      min_size       = var.cpu_min_instance
      max_size       = var.cpu_max_instance
      desired_size   = var.cpu_desired_instance
      instance_types = var.cpu_ec2_instance_types
      capacity_type  = var.cpu_capacity_type
      disk_size      = 100

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
  }

  node_security_group_name = "sg_${local.eks_name}"

  # Disable the module's default (permissive) egress rules which allow public internet access
  node_security_group_enable_recommended_rules = false

  # Explicitly define minimal egress rules that do NOT expose the nodes to the public internet
  node_security_group_additional_rules = {
    # Allow all traffic within the VPC CIDR (private communication)
    egress_to_vpc = {
      description = "Allow egress within VPC"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "egress"
      cidr_blocks = [module.vpc.vpc_cidr_block]
    }

    # Allow nodes to talk to the EKS control plane security group (443/TCP)
    egress_to_cluster = {
      description                   = "Allow egress to cluster API server"
      protocol                     = "tcp"
      from_port                    = 443
      to_port                      = 443
      type                         = "egress"
      source_cluster_security_group = true
    }
  }

  node_security_group_tags = merge(local.tags, {
  })

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
    eks-pod-identity-agent = {
      most_recent = true
    }
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
    chart_version = "8.1.3"
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

module "eks_data_addons" {
  source  = "aws-ia/eks-data-addons/aws"
  version = "~> 1.0"

  oidc_provider_arn = module.eks.oidc_provider_arn

  #---------------------------------------------------------------
  # CloudNative PG Add-on
  #---------------------------------------------------------------
  enable_cnpg_operator = true
  cnpg_operator_helm_config = {
    namespace   = "cnpg-system"
    description = "CloudNativePG Operator Helm chart deployment configuration"
    version     = "0.24.0"
    values = [
      templatefile("${path.module}/files/cnpg.values.yaml", {})
    ]
  }
}