module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"
  
  cluster_name = module.eks.cluster_name

  create_node_iam_role = false

  node_iam_role_arn = module.eks.eks_managed_node_groups["cpu-ng"].iam_role_arn

  # Since the node group role will already have an access entry
  create_access_entry = false

  # Attach additional IAM policies to the Karpenter node IAM role
  # node_iam_role_additional_policies = {
  #   AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  # }

  tags = merge(
    local.tags,
    {}
  )
}