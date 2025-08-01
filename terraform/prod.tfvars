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
cpu_min_instance     = 3
cpu_max_instance     = 10
cpu_desired_instance = 4
cpu_capacity_type    = "SPOT"

mlflow_ec2_instance_types = [
  "g6.2xlarge",
]
mlflow_min_instance     = 0
mlflow_max_instance     = 10
mlflow_desired_instance = 0
mlflow_capacity_type    = "ON_DEMAND"

knative_ec2_instance_types = [
  # a10g
  "g5.xlarge",
  "g5.2xlarge",
  "g5.4xlarge",
  "g5.8xlarge",
  "g5.12xlarge",
  "g5.16xlarge",
  "g5.24xlarge",

  # l4
  "g6.xlarge",
  "g6.2xlarge",
  "g6.4xlarge",
  "g6.8xlarge",
  "g6.12xlarge",
  "g6.16xlarge",
  "g6.24xlarge",
  "g6.48xlarge",

  # l40s
  "g6e.xlarge",
  "g6e.2xlarge",
  "g6e.4xlarge",
  "g6e.8xlarge",
  "g6e.12xlarge",
  "g6e.16xlarge",
  "g6e.24xlarge",
  "g6e.48xlarge",
]
knative_min_instance     = 0
knative_max_instance     = 10
knative_desired_instance = 0
knative_capacity_type    = "ON_DEMAND"

