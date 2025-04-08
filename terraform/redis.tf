module "redis" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 1.0"

  cluster_id               = "${local.name}-cache"
  create_cluster           = true
  create_replication_group = false

  subnet_group_name = "${local.name}-redis"
  node_type         = "cache.t4g.small"
  apply_immediately = true

  log_delivery_configuration = {}

  # Security group
  vpc_id = module.vpc.vpc_id
  security_group_rules = {
    ingress_vpc = {
      # Default type is `ingress`
      # Default port is based on the default engine port
      description = "VPC traffic"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }

  # Subnet Group
  subnet_ids = module.vpc.private_subnets

  tags = merge(local.tags, {
    "Name" = "${local.name}-cache",
  })
}