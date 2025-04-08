module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = local.sg
  description = "Complete PostgreSQL example security group"
  vpc_id = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      description = "PostgreSQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = merge(
    local.tags,
    {}
  )
}

module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 5.0"

  identifier          = "${local.name}-db"
  engine              = "postgres"
  engine_version      = "17.2"
  instance_class      = var.db_instance
  allocated_storage   = 10
  db_name = replace(local.name, "-", "_")
  username            = var.db_username
  password            = var.db_password
  publicly_accessible = false

  family = "postgres17"

  vpc_security_group_ids = [module.security_group.security_group_id]
  db_subnet_group_name    = module.vpc.database_subnet_group
  storage_encrypted       = true
  backup_retention_period = var.db_backup_retention_period

  skip_final_snapshot = var.db_skip_final_snapshot
  deletion_protection = !var.db_skip_final_snapshot

  create_db_subnet_group = false
  create_random_password = false

  create_cloudwatch_log_group = false

  tags = merge(
    local.tags,
    {}
  )
}