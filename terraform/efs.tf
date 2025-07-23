module "efs" {
  source = "terraform-aws-modules/efs/aws"
  version = "~> 1.0"

  # File system
  name           = "${local.name}-efs"
  creation_token = local.name
  encrypted      = true
  kms_key_arn    = module.kms.key_arn

  lifecycle_policy = {
    transition_to_ia                    = "AFTER_30_DAYS"
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  # File system policy
  attach_policy                      = true
  bypass_policy_lockout_safety_check = false

  # Mount targets / security group
  mount_targets              = {for k, v in zipmap(local.azs, module.vpc.private_subnets) : k => { subnet_id = v }}
  security_group_description = "Eks EFS security group"
  security_group_vpc_id      = module.vpc.vpc_id
  security_group_rules = {
    vpc = {
      # relying on the defaults provided for EFS/NFS (2049/TCP + ingress)
      description = "NFS ingress from VPC private subnets"
      cidr_blocks = module.vpc.private_subnets_cidr_blocks
    }
  }

  tags = local.tags
}

module "kms" {
  source  = "terraform-aws-modules/kms/aws"
  version = "~> 1.0"
  
  aliases = ["efs/${local.name}-efs"]
  description           = "EFS customer managed key"
  enable_default_policy = true

  deletion_window_in_days = 10

  tags = local.tags
}