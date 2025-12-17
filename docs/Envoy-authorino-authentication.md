# Envoy and Authorino Authentication Integration Guide

## Table of Contents
- [Introduction](#introduction)
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Deployment](#deployment)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [References](#references)

## Introduction

This guide provides comprehensive instructions for installing and configuring Envoy Gateway and Authorino to work together for API authentication and authorization. Envoy Gateway serves as the API gateway while Authorino provides flexible authentication and authorization capabilities.

## Architecture Overview

The setup includes:
- **Envoy Gateway**: Acts as the API gateway managing traffic routing
- **Authorino**: Provides authentication and authorization services via external auth
- **Kubernetes**: Container orchestration platform
- **Test Application**: HTTPBin service for testing the authentication flow

## Prerequisites

Before starting, ensure you have the following tools and knowledge:

### Required Tools
- [Kubernetes](https://kubernetes.io/) - Container orchestration
- [Authorino](https://github.com/Kuadrant/authorino) - Authorization service
- [Envoy Gateway](https://gateway.envoyproxy.io/) - API gateway
- [Helm](https://helm.sh/) - Kubernetes package manager
- [kubectl](https://kubernetes.io/docs/reference/kubectl/) - Kubernetes CLI
- [curl](https://curl.se/) - HTTP client for testing

### Optional Tools
- [k9s](https://k9s.dev/) - Kubernetes cluster management
- [Multipass](https://multipass.run/) - Ubuntu VM manager

### Installation References
For detailed installation instructions of prerequisites, refer to:
https://github.com/ADORSYS-GIS/crash-k8s/tree/master/1_setup

## Installation

### Step 1: Create Multipass Instance (Optional)

If using Multipass for an isolated environment:

```bash
# Create and launch instance with adequate resources
multipass launch -c 2 -m 4G -d 20G -n ai-ops-authorino 24.04

# Connect to the instance
multipass shell ai-ops-authorino
```

### Step 2: Shell Enhancement (Optional)

For improved shell experience:

```bash
# Install zsh
sudo apt-get update
sudo apt-get install -y zsh

# Install Oh-My-Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Apply configuration
source ~/.zshrc
```

### Step 3: Install Kubernetes (k3s)

```bash
# Install k3s (includes kubectl)
curl -sfL https://get.k3s.io | sh -

# Setup kubeconfig
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 644 ~/.kube/config

# Verify installation
kubectl version --short
```

### Step 4: Install Helm

```bash
# Download and install Helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh

# Verify installation
helm version
```

### Step 5: Install k9s (Optional)

```bash
# Install k9s for cluster visualization
curl -sS https://webinstall.dev/k9s | bash

# Add to PATH if needed
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## Deployment

### Step 1: Install Envoy Gateway

```bash
# Install Envoy Gateway using Helm
helm upgrade -i eg oci://docker.io/envoyproxy/gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-gateway-system \
  --create-namespace \
  -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/manifests/envoy-gateway-values.yaml

# Verify installation
helm status eg -n envoy-gateway-system

# Check pods are running
kubectl get pods -n envoy-gateway-system
```

### Step 2: Install Authorino Operator

```bash
# Install Authorino Operator
kubectl apply -f https://raw.githubusercontent.com/Kuadrant/authorino-operator/main/config/deploy/manifests.yaml

# Wait for operator to be ready
kubectl wait --for=condition=Available deployment/authorino-operator -n authorino-operator --timeout=300s

# Verify installation
kubectl get pods -n authorino-operator
```

### Step 3: Setup Working Directory

```bash
# Create deployment directory
mkdir -p ~/authorino-deployment
cd ~/authorino-deployment
```

### Step 4: Create Namespace and Deploy Authorino Instance

```bash
# Create test namespace
kubectl create namespace test-authorino-v1

# Create Authorino instance configuration
cat <<EOF > authorino.yaml
apiVersion: operator.authorino.kuadrant.io/v1beta1
kind: Authorino
metadata:
  name: authorino
spec:
  listener:
    tls:
      enabled: false
  oidcServer:
    tls:
      enabled: false
EOF

# Deploy Authorino instance
kubectl -n test-authorino-v1 apply -f authorino.yaml

# Wait for Authorino to be ready
kubectl wait --for=condition=Ready authorino/authorino -n test-authorino-v1 --timeout=300s
```

### Step 5: Deploy Test Application

#### Option A: HTTPBin (Recommended)

```bash
# Create HTTPBin deployment
cat <<EOF > httpbin-workload.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
      - name: httpbin
        image: mccutchen/go-httpbin:latest
        imagePullPolicy: Always
        env:
        - name: PORT
          value: "8080"
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  labels:
    app: httpbin
spec:
  selector:
    app: httpbin
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
EOF

# Deploy HTTPBin
kubectl -n test-authorino-v1 apply -f httpbin-workload.yaml

# Wait for deployment
kubectl wait --for=condition=Available deployment/httpbin -n test-authorino-v1 --timeout=300s
```

#### Option B: Talker API (Alternative)

```bash
# Deploy Talker API (may have compatibility issues on some systems)
kubectl apply -f https://raw.githubusercontent.com/kuadrant/authorino-examples/main/talker-api/talker-api-deploy.yaml -n test-authorino-v1
```

### Step 6: Configure Gateway

```bash
# Create Gateway and GatewayClass
cat <<EOF > gateway-example.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: eg
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
EOF

# Apply gateway configuration
kubectl -n test-authorino-v1 apply -f gateway-example.yaml

# Wait for gateway to be ready
kubectl wait --for=condition=Programmed gateway/eg -n test-authorino-v1 --timeout=300s
```

### Step 7: Create HTTP Route

```bash
# Create HTTP route
cat <<EOF > http-route.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: httpbin
spec:
  parentRefs:
    - name: eg
  hostnames:
    - "ai-v1.home.lab"
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - group: ""
          kind: Service
          name: httpbin
          port: 8080
          weight: 1
EOF

# Apply HTTP route
kubectl -n test-authorino-v1 apply -f http-route.yaml
```

### Step 8: Configure Authentication

```bash
# Create AuthConfig for API key authentication
cat <<EOF > authconfig_01.yaml
apiVersion: authorino.kuadrant.io/v1beta3
kind: AuthConfig
metadata:
  name: ai-v1-home-api-protection
spec:
  hosts:
  - ai-v1.home.lab
  authentication:
    "api-clients":
      apiKey:
        selector:
          matchLabels:
            group: friends
      credentials:
        authorizationHeader:
          prefix: APIKEY
EOF

# Apply authentication configuration
kubectl -n test-authorino-v1 apply -f authconfig_01.yaml
```

### Step 9: Configure Security Policy

```bash
# Create SecurityPolicy to integrate Envoy with Authorino
cat <<EOF > security-config.yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: test-authorino-security-policy
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: httpbin
  extAuth:
    grpc:
      backendRefs:
        - name: authorino-authorino-authorization
          namespace: test-authorino-v1
          port: 50051
EOF

# Apply security policy
kubectl -n test-authorino-v1 apply -f security-config.yaml
```

### Step 10: Create API Key Secret

```bash
# Create API key secret for testing
cat <<EOF > api-key-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: api-key-1
  labels:
    authorino.kuadrant.io/managed-by: authorino
    group: friends
type: Opaque
data:
  api_key: $(echo -n "my-secret-api-key" | base64)
EOF

# Apply API key secret
kubectl -n test-authorino-v1 apply -f api-key-secret.yaml
```

## Testing

### Step 1: Set Up Port Forwarding

```bash
# Get the gateway service
kubectl get service -n envoy-gateway-system

# Forward gateway port to localhost
kubectl port-forward service/envoy-eg-$(kubectl get gateway eg -n test-authorino-v1 -o jsonpath='{.metadata.uid}' | cut -c1-8) -n envoy-gateway-system 8080:80 &
```

### Step 2: Test Without Authentication (Should Fail)

```bash
# Test without API key - should return 403 Forbidden
curl -i -H "Host: ai-v1.home.lab" http://localhost:8080/headers

# Expected response: HTTP/1.1 403 Forbidden
```

### Step 3: Test With Authentication (Should Succeed)

```bash
# Test with valid API key
curl -i -H "Host: ai-v1.home.lab" -H "Authorization: APIKEY my-secret-api-key" http://localhost:8080/headers

# Expected response: HTTP/1.1 200 OK with headers
```

### Step 4: Additional Tests

```bash
# Test different endpoints
curl -i -H "Host: ai-v1.home.lab" -H "Authorization: APIKEY my-secret-api-key" http://localhost:8080/ip
curl -i -H "Host: ai-v1.home.lab" -H "Authorization: APIKEY my-secret-api-key" http://localhost:8080/user-agent

# Test with invalid API key - should fail
curl -i -H "Host: ai-v1.home.lab" -H "Authorization: APIKEY invalid-key" http://localhost:8080/headers
```

## Troubleshooting

### Common Issues

#### 1. Gateway Not Ready
```bash
# Check gateway status
kubectl describe gateway eg -n test-authorino-v1

# Check Envoy Gateway logs
kubectl logs -n envoy-gateway-system deployment/envoy-gateway
```

#### 2. Authorino Not Working
```bash
# Check Authorino instance status
kubectl get authorino -n test-authorino-v1

# Check Authorino logs
kubectl logs -n test-authorino-v1 deployment/authorino-authorino
```

#### 3. Authentication Failures
```bash
# Verify AuthConfig
kubectl get authconfig -n test-authorino-v1

# Check if API key secret exists and has correct labels
kubectl get secrets -n test-authorino-v1 --show-labels
```

#### 4. Connection Issues
```bash
# Verify all services are running
kubectl get pods,svc -n test-authorino-v1

# Check if port-forwarding is active
ps aux | grep kubectl | grep port-forward
```

### Debug Commands

```bash
# View all resources in the namespace
kubectl get all -n test-authorino-v1

# Check events for issues
kubectl get events -n test-authorino-v1 --sort-by=.metadata.creationTimestamp

# Describe problematic resources
kubectl describe httproute httpbin -n test-authorino-v1
kubectl describe securitypolicy test-authorino-security-policy -n test-authorino-v1
```

## Cleanup

### Remove Test Resources

```bash
# Stop port forwarding
pkill -f "kubectl port-forward"

# Delete the test namespace (removes all resources)
kubectl delete namespace test-authorino-v1

# Remove Authorino operator
kubectl delete -f https://raw.githubusercontent.com/Kuadrant/authorino-operator/main/config/deploy/manifests.yaml

# Remove Envoy Gateway
helm uninstall eg -n envoy-gateway-system
kubectl delete namespace envoy-gateway-system
```

### Clean Up Multipass (If Used)

```bash
# Exit the multipass instance
exit

# Delete the instance
multipass delete ai-ops-authorino
multipass purge
```

## References

- [Authorino Documentation](https://docs.kuadrant.io/authorino/)
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Kuadrant Examples](https://github.com/kuadrant/authorino-examples)
- [Setup Prerequisites](https://github.com/ADORSYS-GIS/crash-k8s/tree/master/1_setup)

---

**Note**: This guide assumes a development/testing environment. For production deployments, additional security considerations, monitoring, and high availability configurations should be implemented.