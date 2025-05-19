# module "karpenter_sg" {
#   source  = "terraform-aws-modules/security-group/aws"
#   version = "~> 4.0"
# 
#   name        = local.karpenter_sg
#   description = "Security group for Karpenter"
#   vpc_id = module.vpc.vpc_id
# 
#   # Recommended ingress rules
#   ingress_with_source_security_group_id = [
#     {
#       rule                     = "all-all"
#       source_security_group_id = module.eks.cluster_primary_security_group_id
#     }
#   ]
# 
#   # Egress rules to allow node communication
#   egress_rules = ["all-all"]
# 
#   tags = merge(
#     local.tags,
#     {
#       "karpenter.sh/discovery" = local.eks_name
#     }
#   )
# }