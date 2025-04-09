vpc_cidr = "111.11.0.0/16"
azs = [
  "eu-central-1a",
  "eu-central-1b",
  "eu-central-1c"
]

db_instance = "db.t3.medium"
environment = "prod"

eks_ec2_instance_types = [
  "t2.medium",
  "t2.large",
]
eks_min_instance     = 0
eks_max_instance     = 6
eks_desired_instance = 2

eks_gpu_ec2_instance_types = [
  "g4dn.xlarge",
  "g5.xlarge"
]
eks_gpu_min_instance     = 1
eks_gpu_max_instance     = 2
eks_gpu_desired_instance = 2

db_backup_retention_period = null
db_skip_final_snapshot     = true

