module "gpu-operator" {
  source  = "blackbird-cloud/deployment/helm"
  version = "~> 1.0"

  name             = "gpu-operator"
  namespace        = "gpu-operator"
  create_namespace = true
  cleanup_on_fail  = true
  wait             = true
  force_update     = true

  repository    = "https://helm.ngc.nvidia.com/nvidia"
  chart         = "gpu-operator"
  chart_version = "v25.3.0"

  values = [
    templatefile("${path.module}/files/gpu-operator.values.yaml", {})
  ]
}

module "nim-operator" {
  source  = "blackbird-cloud/deployment/helm"
  version = "~> 1.0"

  name             = "nim-operator"
  namespace        = "nim-operator"
  create_namespace = true
  cleanup_on_fail  = true
  wait             = true
  force_update     = true

  repository    = "https://helm.ngc.nvidia.com/nvidia"
  chart         = "k8s-nim-operator"
  chart_version = "1.0.1"

  values = [
    templatefile("${path.module}/files/nim-nvidia.values.yaml", {})
  ]

}