data "aws_route53_zone" "selected" {
  name = "${var.zone_name}."
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}