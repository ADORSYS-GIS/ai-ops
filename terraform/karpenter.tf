module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.0"
  
  cluster_name = module.eks.cluster_name
  enable_v1_permissions = true
  create_pod_identity_association = true

  create_node_iam_role = false

  node_iam_role_arn = module.eks.eks_managed_node_groups["knative-ng"].iam_role_arn

  create_access_entry = false

  tags = merge(
    local.tags,
    {}
  )
}

module "karpenter-helm" {
  source  = "blackbird-cloud/deployment/helm"
  version = "~> 1.0"

  name             = "karpenter"
  namespace        = "kube-system"
  create_namespace = false

  repository    = "oci://public.ecr.aws/karpenter"
  chart         = "karpenter"
  chart_version = "1.4.0"

  values = [
    templatefile("${path.module}/files/karpenter.yaml", {
      clusterName: local.eks_name
      clusterEndpoint: module.eks.cluster_endpoint
      interruptionQueue: module.karpenter.queue_name
    })
  ]

  cleanup_on_fail = false
  wait            = false
}