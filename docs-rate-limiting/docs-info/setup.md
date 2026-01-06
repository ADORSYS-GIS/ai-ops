# Environment Setup: K3s and Envoy AI Gateway

This guide walks through the installation of **K3s**, **Envoy Gateway**, and the **Envoy AI Gateway** components.

---

## 1. Install K3s

Install K3s using the official installation script:

```bash
curl -sfL https://get.k3s.io | sh -
```

# Install Envoy

## 1. Install Envoy Gateway

```bash
helm upgrade -i eg oci://docker.io/envoyproxy/gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-gateway-system \
  --create-namespace \
  -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/manifests/envoy-gateway-values.yaml

kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```


## 2. Install AI Gateway CRDs

```bash
helm upgrade -i aieg-crd oci://docker.io/envoyproxy/ai-gateway-crds-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace
```

## 3. Install AI Gateway Controller

```bash
helm upgrade -i aieg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace

kubectl wait --timeout=2m -n envoy-ai-gateway-system deployment/ai-gateway-controller --for=condition=Available
```
