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
cpu_min_instance     = 1
cpu_max_instance     = 5
cpu_desired_instance = 2
cpu_capacity_type    = "ON_DEMAND"

sandbox_min_instance     = 1
sandbox_max_instance     = 10
sandbox_desired_instance = 4
sandbox_capacity_type    = "SPOT"
sandbox_ec2_instance_types = [
  "t3.medium",
  "t3.large"
]

other_zone_names = []
