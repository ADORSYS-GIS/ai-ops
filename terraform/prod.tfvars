vpc_cidr = "111.11.0.0/16"
azs = [
  "eu-central-1a",
  "eu-central-1b",
  "eu-central-1c"
]

environment = "prod"

eks_ec2_instance_types = [
  "t2.medium",
]
eks_min_instance     = 0
eks_max_instance     = 10
eks_desired_instance = 1

eks_gpu_ec2_instance_types = [
  "g6.2xlarge",
]
eks_gpu_min_instance     = 0
eks_gpu_max_instance     = 10
eks_gpu_desired_instance = 1

db_backup_retention_period = null

