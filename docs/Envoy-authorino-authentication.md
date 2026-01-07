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

**Expected output:**
```
Launching ai-ops-authorino...
Launched: ai-ops-authorino
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

# IMPORTANT: Export KUBECONFIG environment variable
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc

# Verify installation
kubectl version
```

**Expected output:**
```
Client Version: v1.28.x-k3s1
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
Server Version: v1.28.x-k3s1
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

**Expected output:**
```
version.BuildInfo{Version:"v3.x.x", GitCommit:"...", GitTreeState:"clean", GoVersion:"go1.x.x"}
```

### Step 5: Install k9s (Optional)

**Note:** k9s installation may fail when run as batch commands. Install manually if needed.

```bash
# Install k9s for cluster visualization
curl -sS https://webinstall.dev/k9s | bash

# Wait for installation to complete before proceeding
sleep 5

# Add to PATH and source
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify installation works
k9s version
```

**If k9s installation fails, use alternative method:**
```bash
# Alternative: Manual installation
wget https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/
```

## Deployment

### Step 1: Install Envoy Gateway

```bash
# Install Envoy Gateway using Helm
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.6.1 \
  -n envoy-gateway-system \
  --create-namespace

# Verify installation
helm status eg -n envoy-gateway-system

# Check pods are running - wait until all are Ready
kubectl get pods -n envoy-gateway-system -w
```

**Expected output:**
```
NAME                             READY   STATUS    RESTARTS   AGE
envoy-gateway-64d8866b44-jqf4d   1/1     Running   0          40s
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

**Expected output:**
```
NAME                                  READY   STATUS    RESTARTS   AGE
authorino-operator-xxxxxxxxx-xxxxx   1/1     Running   0          1m
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

**Expected output:**
```
authorino.operator.authorino.kuadrant.io/authorino condition met
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

# Wait for deployment to be ready
kubectl wait --for=condition=Available deployment/httpbin -n test-authorino-v1 --timeout=300s
```

**Expected output:**
```
deployment.apps/httpbin condition met
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
```
```sh
# Get svc in the envoy-gateway-system
kubectl get svc -n envoy-gateway-system
```
Look for the resource that is named like envoy-test-authorino-v1-eg*, copy it's name and use in the command below
```sh
# Patch NodePort
kubectl patch svc [envoy-test-authorino-v1-eg*] \
  -n envoy-gateway-system \
  -p '{"spec":{"type":"NodePort"}}'
```
```sh
# Wait for gateway to be programmed
kubectl wait --for=condition=Programmed gateway/eg -n test-authorino-v1 --timeout=300s
```

**Expected output:**
```
gateway.gateway.networking.k8s.io/eg condition met
```

**If gateway condition is not met, check status:**
```bash
kubectl describe gateway eg -n test-authorino-v1
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

# Verify route is accepted
kubectl get httproute httpbin -n test-authorino-v1 -o yaml | grep -A5 conditions
```

**Expected output should show:**
```
conditions:
- type: Accepted
  status: "True"
```

### Step 8: Configure Authentication

```bash
# Create AuthConfig for API key authentication
cat <<EOF > authconfig.yaml
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
kubectl -n test-authorino-v1 apply -f authconfig.yaml

# Verify AuthConfig is ready
kubectl get authconfig -n test-authorino-v1
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

# Verify policy is accepted
kubectl get securitypolicy -n test-authorino-v1
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

# Verify secret exists with correct labels
kubectl get secrets -n test-authorino-v1 --show-labels | grep friends
```

**Expected output:**
```
api-key-1   Opaque   1   1m   authorino.kuadrant.io/managed-by=authorino,group=friends
```

## Testing

### Step 1: Verify All Components Are Ready

```bash
# Check all pods are running
kubectl get pods -n test-authorino-v1

# Check gateway is programmed
kubectl get gateway eg -n test-authorino-v1 -o jsonpath='{.status.conditions[?(@.type=="Programmed")].status}'

# Should output: True
```

### Step 2: Set Up Port Forwarding

First, find the Envoy service created by the gateway:

```bash
# List services in envoy-gateway-system to find the Envoy service
kubectl get svc -n envoy-gateway-system
```

**Expected output (look for a service starting with "envoy-"):**
```
NAME                                    TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)
envoy-test-authorino-v1-eg-xxxxx        LoadBalancer   10.43.xx.xx    <pending>     80:xxxxx/TCP
```

Now set up port forwarding using the service name you found:

```bash
# Replace [SERVICE_NAME] with the actual service name from above
kubectl port-forward -n envoy-gateway-system service/[SERVICE_NAME] 8080:80 &
```

**Example with actual service name:**
```bash
# Example: if service name is envoy-test-authorino-v1-eg-12345
kubectl port-forward -n envoy-gateway-system service/envoy-test-authorino-v1-eg-12345 8080:80 &
```

**If no service is found, try this alternative method:**
```bash
# Find services by gateway label
kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-namespace=test-authorino-v1
```

### Step 3: Test Without Authentication (Should Fail)

```bash
# Test without API key - should return 401 Unauthorized
curl -i -H "Host: ai-v1.home.lab" http://localhost:8080/headers
```

**Expected output:**
```
HTTP/1.1 401 Unauthorized
www-authenticate: APIKEY realm="api-clients"
x-ext-auth-reason: credential not found
date: Wed, 07 Jan 2026 10:09:23 GMT
content-length: 0

```

### Step 4: Test With Authentication (Should Succeed)

```bash
# Test with valid API key
curl -i -H "Host: ai-v1.home.lab" -H "Authorization: APIKEY my-secret-api-key" http://localhost:8080/headers
```

**Expected output:**
```
HTTP/1.1 200 OK
access-control-allow-credentials: true
access-control-allow-origin: *
content-type: application/json; charset=utf-8
date: Wed, 07 Jan 2026 11:15:56 GMT
content-length: 442

{
  "headers": {
    "Accept": [
      "*/*"
    ],
    "Authorization": [
      "APIKEY my-secret-api-key"
    ],
    "Host": [
      "ai-v1.home.lab"
    ],
    "User-Agent": [
      "curl/7.81.0"
    ],
    "X-Envoy-External-Address": [
      "127.0.0.1"
    ],
    "X-Forwarded-For": [
      "10.42.0.14"
    ],
    "X-Forwarded-Proto": [
      "http"
    ],
    "X-Request-Id": [
      "d62eeff2-c156-4108-b066-e983135724ad"
    ]
  }
}


```

### Step 5: Additional Tests

```bash
# Test different endpoints
curl -i -H "Host: ai-v1.home.lab" -H "Authorization: APIKEY my-secret-api-key" http://localhost:8080/ip
curl -i -H "Host: ai-v1.home.lab" -H "Authorization: APIKEY my-secret-api-key" http://localhost:8080/user-agent

# Test with invalid API key - should fail
curl -i -H "Host: ai-v1.home.lab" -H "Authorization: APIKEY invalid-key" http://localhost:8080/headers
```

**Expected output for invalid key:**
```
HTTP/1.1 401 Unauthorized
```

## Troubleshooting

### Common Issues and Solutions

#### 1. KUBECONFIG Issues
**Problem**: Permission denied or kubectl commands fail
**Solution**:
```bash
# Ensure KUBECONFIG is set
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
source ~/.bashrc

# Check file permissions
ls -la ~/.kube/config
# Should show -rw-r--r--

# If permissions are wrong:
chmod 644 ~/.kube/config
```

#### 2. k9s Installation Fails
**Problem**: k9s installation fails when running commands in batch
**Solution**:
```bash
# Install k9s manually step by step
wget https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz
tar -xzf k9s_Linux_amd64.tar.gz
sudo mv k9s /usr/local/bin/
rm k9s_Linux_amd64.tar.gz

# Verify installation
k9s version
```

#### 3. Gateway Condition Not Programmed
**Problem**: Gateway condition "Programmed" is not met
**Solution**:
```bash
# Check gateway status
kubectl describe gateway eg -n test-authorino-v1

# Look for issues in events
kubectl get events -n test-authorino-v1 --sort-by=.metadata.creationTimestamp

# Check Envoy Gateway controller logs
kubectl logs -n envoy-gateway-system deployment/envoy-gateway -f

# Verify GatewayClass exists
kubectl get gatewayclass

# If issues persist, recreate gateway:
kubectl delete gateway eg -n test-authorino-v1
kubectl apply -f gateway-example.yaml -n test-authorino-v1
```

#### 4. Port-Forwarding Fails - No Envoy Service Found
**Problem**: Cannot find envoy service for port forwarding
**Solution**:
```bash
# Step 1: List all services in envoy-gateway-system
kubectl get svc -n envoy-gateway-system

# Step 2: If no services found, check gateway status
kubectl get gateway eg -n test-authorino-v1

# Step 3: Wait for gateway to create service (may take a few minutes)
kubectl wait --for=condition=Programmed gateway/eg -n test-authorino-v1 --timeout=300s

# Step 4: Try again to list services
kubectl get svc -n envoy-gateway-system

# Step 5: Use the service name that appears (usually starts with envoy-test-authorino-v1-eg-)
kubectl port-forward -n envoy-gateway-system service/[SERVICE_NAME] 8080:80 &
```

#### 5. Port-Forward Connection Drops During Testing
**Problem**: Port forwarding stops working when making requests
**Solution**:
```bash
# Step 1: Stop existing port forwards
pkill -f "kubectl port-forward"

# Step 2: Start port forwarding in foreground (easier to monitor)
kubectl port-forward -n envoy-gateway-system service/[SERVICE_NAME] 8080:80

# Alternative: If still having issues, try a different port
kubectl port-forward -n envoy-gateway-system service/[SERVICE_NAME] 8081:80 &

# Test with the new port
curl -i -H "Host: ai-v1.home.lab" http://localhost:8081/headers
```

#### 6. Authentication Always Fails
**Problem**: All requests return 403 even with correct API key
**Solution**:
```bash
# Verify Authorino is running
kubectl get pods -n test-authorino-v1 | grep authorino

# Check Authorino logs
kubectl logs -n test-authorino-v1 deployment/authorino-authorino -f

# Verify AuthConfig is applied
kubectl get authconfig -n test-authorino-v1 -o yaml

# Check if API key secret has correct labels
kubectl get secrets -n test-authorino-v1 --show-labels | grep group=friends

# Verify SecurityPolicy is properly linked
kubectl describe securitypolicy test-authorino-security-policy -n test-authorino-v1

# Test Authorino service directly
kubectl port-forward -n test-authorino-v1 service/authorino-authorino-authorization 50051:50051 &
```

#### 7. HTTPBin Not Responding
**Problem**: Backend service is not reachable
**Solution**:
```bash
# Check HTTPBin pod status
kubectl get pods -n test-authorino-v1 -l app=httpbin

# Verify service exists
kubectl get svc -n test-authorino-v1 httpbin

# Test service directly
kubectl port-forward -n test-authorino-v1 service/httpbin 8082:8080 &
curl localhost:8082/headers

# Check HTTPBin logs
kubectl logs -n test-authorino-v1 deployment/httpbin
```

### Debug Commands

```bash
# Comprehensive namespace overview
kubectl get all -n test-authorino-v1

# Check all events in namespace
kubectl get events -n test-authorino-v1 --sort-by=.metadata.creationTimestamp

# Describe all custom resources
kubectl describe gateway eg -n test-authorino-v1
kubectl describe httproute httpbin -n test-authorino-v1
kubectl describe securitypolicy test-authorino-security-policy -n test-authorino-v1
kubectl describe authconfig ai-v1-home-api-protection -n test-authorino-v1

# Check running processes
ps aux | grep kubectl | grep port-forward

# Network connectivity test
kubectl run -it --rm debug --image=nicolaka/netshoot --restart=Never -- nslookup httpbin.test-authorino-v1.svc.cluster.local
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

# [To test with talker API instead of httpbin](https://github.com/Kuadrant/authorino/blob/main/docs/user-guides/hello-world.md)