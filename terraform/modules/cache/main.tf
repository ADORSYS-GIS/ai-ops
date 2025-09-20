module "redis" {
  source  = "terraform-aws-modules/elasticache/aws"
  version = "~> 1.0"

  cluster_id               = "${var.name}-cache"
  create_cluster           = true
  create_replication_group = false

  subnet_group_name = "${var.name}-cache"
  node_type         = "cache.t4g.small"
  apply_immediately = true

  log_delivery_configuration = {}

  # Security group
  vpc_id = var.vpc_id
  security_group_rules = {
    ingress_vpc = {
      # Default type is `ingress`
      # Default port is based on the default engine port
      description = "VPC traffic"
      cidr_ipv4   = var.cidr_ipv4
    }
  }

  # Subnet Group
  subnet_ids = var.subnet_ids

  tags = merge(local.tags, {
    "Name" = "${var.name}-cache",
  })
}

locals {
  redis_node = module.redis.cluster_cache_nodes[0]
  redis_url  = "redis://${local.redis_node.address}:${local.redis_node.port}"
  tags       = merge({}, var.tags)
}
