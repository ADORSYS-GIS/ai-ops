vpc_cidr = "111.11.0.0/16"
azs = [
  "eu-central-1a",
  "eu-central-1b",
  "eu-central-1c"
]

environment = "prod"

cpu_ec2_instance_types = [
  "t3.medium",
  "t3.large",
  "t3.xlarge",
  
  "c5.large",
  "c5.xlarge"
]
cpu_min_instance     = 2
cpu_max_instance     = 10
cpu_desired_instance = 3
cpu_capacity_type    = "ON_DEMAND"
