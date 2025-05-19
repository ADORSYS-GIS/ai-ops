module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"
  
  cluster_name = module.eks.cluster_name
  enable_v1_permissions = true
  create_pod_identity_association = true

  create_node_iam_role = false

  node_iam_role_arn = module.eks.eks_managed_node_groups["karpenter-ng"].iam_role_arn

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

module "ops" {
  source  = "blackbird-cloud/deployment/helm"
  version = "~> 1.0"

  name             = "karpenter"
  namespace        = "kube-system"
  create_namespace = false

  repository    = "oci://public.ecr.aws/karpenter"
  chart         = "rakarpenterw"
  chart_version = "1.4.0"

  values = [
    templatefile("${path.module}/files/karpenter.yaml", {
      clusterName: module.eks.cluster_name
      clusterEndpoint: module.eks.cluster_endpoint
      interruptionQueue: module.karpenter.queue_name
    })
  ]

  # cleanup_on_fail = false
  wait            = false
}