# Envoy AI Gateway: Model Name Virtualization & Provider Fallback

## Table of Contents
1. [Overview](#overview)
2. [References](#references)
3. [Environment Setup](#environment-setup)
4. [Ticket 1: Model Name Virtualization](#ticket-1-model-name-virtualization)
5. [Ticket 2: Provider Fallback](#ticket-2-provider-fallback)
6. [Troubleshooting](#troubleshooting)
---

## Overview

**Model Name Virtualization**: Abstract actual model names behind virtual names. Clients use stable virtual names while the gateway routes to actual backend models.

**Provider Fallback**: Automatic failover between primary and fallback AI models. When primary fails, requests automatically route to fallback backends based on priority.

---

## References

### Official Documentation
- [Envoy AI Gateway - Getting Started Installation](https://aigateway.envoyproxy.io/docs/getting-started/installation)
- [Envoy AI Gateway - Model Name Virtualization](https://aigateway.envoyproxy.io/docs/capabilities/traffic/model-name-virtualization)
- [Envoy AI Gateway - Provider Fallback](https://aigateway.envoyproxy.io/docs/capabilities/traffic/provider-fallback)
- [KServe - Serverless Installation](https://kserve.github.io/website/docs/admin-guide/serverless)
- [Knative - Install Serving with YAML](https://knative.dev/docs/install/yaml-install/serving/install-serving-with-yaml/#verify-the-installation)
- [Knative - Install Istio for Knative](https://knative.dev/docs/install/yaml-install/serving/install-serving-with-yaml/#install-a-networking-layer)
- [Cert Manager - Installation](https://cert-manager.io/docs/installation/)


---

## Environment Setup

You can choose between two approaches for your Kubernetes cluster:

### Option A: Using Multipass VM

#### Create VM
```bash
multipass launch --name aiops --cpus 10 --mem 30G --disk 50G
multipass shell aiops
```

#### Install K3s
```bash
curl -sfL https://get.k3s.io | sh -
mkdir ~/.kube
sudo cp -r /etc/rancher/k3s/k3s.yaml ~/.kube/config 
sudo chmod 644 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
```

### Option B: Using k3d (Docker-based)

**Prerequisites**: Ensure Docker is installed and running on your system.

#### Install k3d
```bash
# Linux/macOS
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Or using wget
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Verify installation
k3d version
```

#### Create k3d Cluster
```bash
# Create cluster with appropriate resources
k3d cluster create aiops \
  --image rancher/k3s:v1.32.0-k3s1 \
  --wait

# Set kubeconfig
export KUBECONFIG="$(k3d kubeconfig write aiops)"
echo "export KUBECONFIG=$(k3d kubeconfig write aiops)" >> ~/.bashrc

# Verify cluster
kubectl cluster-info
kubectl get nodes

```


#### k3d Cluster Management Commands
```bash
# Stop cluster
k3d cluster stop aiops

# Start cluster
k3d cluster start aiops

# Delete cluster
k3d cluster delete aiops

# List clusters
k3d cluster list
```

---

### Common Setup (Both Options)

### Install Helm
```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

### Install K9s (Optional)
```bash
curl -sS https://webinstall.dev/k9s | sh
```

### Install Envoy AI Gateway

**Install Envoy Gateway**
```bash
helm upgrade -i eg oci://docker.io/envoyproxy/gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-gateway-system \
  --create-namespace \
  -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/manifests/envoy-gateway-values.yaml

kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

**Install AI Gateway CRDs**
```bash
helm upgrade -i aieg-crd oci://docker.io/envoyproxy/ai-gateway-crds-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace
```
**Install AI Gateway Resources**
```bash
helm upgrade -i aieg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace

kubectl wait --timeout=2m -n envoy-ai-gateway-system deployment/ai-gateway-controller --for=condition=Available
```
**Verify Installation**
```bash
kubectl get pods -n envoy-ai-gateway-system
```

### Install KServe

**Install Knative Serving:**
```bash
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.20.0/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.20.0/serving-core.yaml
```

**Install Istio:**
```bash
kubectl apply -l knative.dev/crd-install=true -f https://github.com/knative-extensions/net-istio/releases/download/knative-v1.20.1/istio.yaml
kubectl apply -f https://github.com/knative-extensions/net-istio/releases/download/knative-v1.20.1/istio.yaml
kubectl apply -f https://github.com/knative/net-istio/releases/download/knative-v1.20.1/net-istio.yaml
```

**Install Cert Manager:**
```bash
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.yaml
kubectl wait --for=condition=Available -n cert-manager deployment/cert-manager-webhook
```

**Install KServe:**
```bash
helm install kserve-crd oci://ghcr.io/kserve/charts/kserve-crd --version v0.12.0
helm install kserve oci://ghcr.io/kserve/charts/kserve --version v0.12.0
```

**Verify Overall Setup**
```bash
kubectl get pods -A
```

---

## Ticket 1: Model Name Virtualization

**Goal**: Connect multiple KServe models to Envoy AI Gateway using the same virtual model name. Route requests based on weight distribution.

### Step 1: Create Model Files

**File: `primary-model.yaml`**
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: qwen-primary
  namespace: default
spec:
  predictor:
    containers:
      - name: kserve-container
        image: ollama/ollama:latest
        ports:
          - containerPort: 11434
            protocol: TCP
        command: ["/bin/bash", "-c"]
        args:
          - "ollama serve & sleep 5 && ollama pull qwen2.5:1.5b && wait"
        resources:
          requests:
            cpu: "1"
            memory: "1Gi"
          limits:
            cpu: "2"
            memory: "2Gi"
```

**File: `secondary-model.yaml`**
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: qwen-secondary
  namespace: default
spec:
  predictor:
    containers:
      - name: kserve-container
        image: ollama/ollama:latest
        ports:
          - containerPort: 11434
            protocol: TCP
        command: ["/bin/bash", "-c"]
        args:
          - "ollama serve & sleep 5 && ollama pull qwen2.5:0.5b && wait"
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "2"
            memory: "2Gi"
```

**File: `tertiary-model.yaml`**
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: qwen-tertiary
  namespace: default
spec:
  predictor:
    containers:
      - name: kserve-container
        image: ollama/ollama:latest
        ports:
          - containerPort: 11434
            protocol: TCP
        command: ["/bin/bash", "-c"]
        args:
          - "ollama serve & sleep 5 && ollama pull qwen2.5:0.5b && wait"
        resources:
          requests:
            cpu: "1"
            memory: "2Gi"
          limits:
            cpu: "2"
            memory: "2Gi"
```

### Step 2: Deploy Models
```bash
kubectl apply -f tertiary-model.yaml
kubectl get pods -n default
kubectl get isvc -n default -w
```
```bash

kubectl apply -f secondary-model.yaml
kubectl apply -f primary-model.yaml
```

Monitor deployment:
```bash
kubectl get pods -n default
kubectl get isvc -n default -w
```

Wait until all show `READY=True`.

![Model Deployment Status](images/ticket1-model-deployment.png)
*Figure 1: InferenceServices showing READY=True status*

### Step 3: Create Gateway Configuration

**File: `gateway-setup.yaml`**
```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: envoy-ai-gateway-basic
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: envoy-ai-gateway-basic
  namespace: default
spec:
  gatewayClassName: envoy-ai-gateway-basic
  listeners:
    - name: http
      protocol: HTTP
      port: 80
  infrastructure:
    parametersRef:
      group: gateway.envoyproxy.io
      kind: EnvoyProxy
      name: envoy-ai-gateway-basic
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: ClientTrafficPolicy
metadata:
  name: client-buffer-limit
  namespace: default
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: envoy-ai-gateway-basic
  connection:
    bufferLimit: 50Mi
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: envoy-ai-gateway-basic
  namespace: default
spec:
  provider:
    type: Kubernetes
    kubernetes:
      envoyDeployment:
        container:
          resources: {}
```

### Step 4: Create Model Virtualization Routing

**File: `model-virtualization.yaml`**
```yaml
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIGatewayRoute
metadata:
  name: envoy-ai-gateway-virtualization
  namespace: default
spec:
  parentRefs:
    - name: envoy-ai-gateway-basic
      kind: Gateway
      group: gateway.networking.k8s.io
  rules:
    - matches:
        - headers:
            - type: Exact
              name: x-ai-eg-model
              value: virtual-qwen-model
      backendRefs:
        - name: envoy-ai-gateway-qwen-primary
          modelNameOverride: qwen2.5:1.5b
          weight: 50
        - name: envoy-ai-gateway-qwen-secondary
          modelNameOverride: qwen2.5:0.5b
          weight: 30
        - name: envoy-ai-gateway-qwen-tertiary
          modelNameOverride: qwen2.5:0.5b
          weight: 20
---
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIServiceBackend
metadata:
  name: envoy-ai-gateway-qwen-primary
  namespace: default
spec:
  schema:
    name: OpenAI
  backendRef:
    name: envoy-ai-gateway-qwen-primary
    kind: Backend
    group: gateway.envoyproxy.io
---
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIServiceBackend
metadata:
  name: envoy-ai-gateway-qwen-secondary
  namespace: default
spec:
  schema:
    name: OpenAI
  backendRef:
    name: envoy-ai-gateway-qwen-secondary
    kind: Backend
    group: gateway.envoyproxy.io
---
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIServiceBackend
metadata:
  name: envoy-ai-gateway-qwen-tertiary
  namespace: default
spec:
  schema:
    name: OpenAI
  backendRef:
    name: envoy-ai-gateway-qwen-tertiary
    kind: Backend
    group: gateway.envoyproxy.io
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata:
  name: envoy-ai-gateway-qwen-primary
  namespace: default
spec:
  endpoints:
    - fqdn:
        hostname: qwen-primary-predictor-00001.default.svc.cluster.local
        port: 80
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata:
  name: envoy-ai-gateway-qwen-secondary
  namespace: default
spec:
  endpoints:
    - fqdn:
        hostname: qwen-secondary-predictor-00001.default.svc.cluster.local
        port: 80
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata:
  name: envoy-ai-gateway-qwen-tertiary
  namespace: default
spec:
  endpoints:
    - fqdn:
        hostname: qwen-tertiary-predictor-00001.default.svc.cluster.local
        port: 80
```

**Key Configuration**:
- `x-ai-eg-model: virtual-qwen-model` - Client uses this virtual name as seen in the curl request used for testing 
- `modelNameOverride` - Gateway translates to actual model names; that can be verified in the responses and the logs.
- `weight` - Traffic distribution (50% primary, 30% secondary, 20% tertiary)

### Step 5: Apply Configuration
```bash
kubectl apply -f gateway-setup.yaml
kubectl apply -f model-virtualization.yaml
```

Wait for gateway:
```bash
kubectl wait pods --timeout=2m \
  -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -n envoy-gateway-system \
  --for=condition=Ready
```

### Step 6: Setup Port Forward

```bash
export ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')

kubectl port-forward -n envoy-gateway-system svc/$ENVOY_SERVICE 8080:80
```


### Step 7: Test Model Virtualization
```bash
export GATEWAY_URL="http://localhost:8080"

curl -H "Content-Type: application/json" \
  -d '{
        "model": "virtual-qwen-model",
        "messages": [
            {
                "role": "user",
                "content": "Explain AI in simple terms."
            }
        ],
        "max_tokens": 100
    }' \
  $GATEWAY_URL/v1/chat/completions
```


**Expected Result**: 
- Request succeeds with virtual model name
- Traffic distributed: 50% to primary (1.5b), 30% to secondary (0.5b), 20% to tertiary (0.5b)
- Client unaware of actual model names

![Successful Response](images/ticket1-successful-response.png)
*Figure 2: Example of successful virtualized model response*


**Test Multiple Times**:
```bash
for i in {1..10}; do
  echo "Request $i"
  curl -s -H "Content-Type: application/json" \
    -d '{"model": "virtual-qwen-model", "messages": [{"role": "user", "content": "Hi"}], "max_tokens": 50}' \
    $GATEWAY_URL/v1/chat/completions | jq -r '.choices[0].message.content'
  echo "---"
done
```

You should see requests distributed across backends according to weights.

**Monitor Behavior**

Watch logs to observe model virtualization:
```bash
kubectl logs -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  --tail=50 -f
```

![Gateway Logs - Virtualization](images/ticket1-gateway-logs.png)
*Figure 3: Gateway logs showing traffic distribution across backends*

---

## Ticket 2: Provider Fallback

**Goal**: Configure primary model with automatic fallback using existing models from Ticket 1. Test by deleting primary isvc to verify failover to secondary model.

**Note**: This ticket reuses the `qwen-primary` and `qwen-secondary` models from Ticket 1, so you don't need to deploy new models.

### Step 1: Verify Existing Models

Ensure models from Ticket 1 are still running:
```bash
kubectl get isvc -n default
kubectl get pods -n default | grep qwen
```

You should see `qwen-primary` and `qwen-secondary` with READY=True status.



### Step 2: Create Fallback Gateway Configuration

**File: `provider-fallback.yaml`**
```yaml
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIGatewayRoute
metadata:
  name: envoy-ai-gateway-fallback
  namespace: default
spec:
  parentRefs:
    - name: envoy-ai-gateway-basic
      kind: Gateway
      group: gateway.networking.k8s.io
  rules:
    - matches:
        - headers:
            - type: Exact
              name: x-ai-eg-model
              value: qwen-with-fallback
      backendRefs:
        - name: envoy-ai-gateway-qwen-primary-fb
          modelNameOverride: qwen2.5:1.5b
          priority: 0
        - name: envoy-ai-gateway-qwen-secondary-fb
          modelNameOverride: qwen2.5:0.5b
          priority: 1
---
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIServiceBackend
metadata:
  name: envoy-ai-gateway-qwen-primary-fb
  namespace: default
spec:
  schema:
    name: OpenAI
  backendRef:
    name: envoy-ai-gateway-qwen-primary-fb
    kind: Backend
    group: gateway.envoyproxy.io
---
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIServiceBackend
metadata:
  name: envoy-ai-gateway-qwen-secondary-fb
  namespace: default
spec:
  schema:
    name: OpenAI
  backendRef:
    name: envoy-ai-gateway-qwen-secondary-fb
    kind: Backend
    group: gateway.envoyproxy.io
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata:
  name: envoy-ai-gateway-qwen-primary-fb
  namespace: default
spec:
  endpoints:
    - fqdn:
        hostname: qwen-primary-predictor-00001.default.svc.cluster.local
        port: 80
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata:
  name: envoy-ai-gateway-qwen-secondary-fb
  namespace: default
spec:
  endpoints:
    - fqdn:
        hostname: qwen-secondary-predictor-00001.default.svc.cluster.local
        port: 80
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: envoy-ai-gateway-fallback-policy
  namespace: default
spec:
  targetRefs:
    - group: gateway.envoyproxy.io
      kind: Gateway
      name: envoy-ai-gateway-basic
  retry:
    numRetries: 3
    perRetry:
      backOff:
        baseInterval: 100ms
        maxInterval: 10s
      timeout: 30s
    retryOn:
      httpStatusCodes:
        - 500
        - 502
        - 503
        - 504
        - 404
      triggers:
        - connect-failure
        - retriable-status-codes
```

**Key Configuration**:
- Reuses existing `qwen-primary` and `qwen-secondary` services
- `priority: 0` - Primary model (qwen2.5:1.5b) tried first
- `priority: 1` - Fallback to secondary model (qwen2.5:0.5b) if primary fails
- `numRetries: 3` - Total retry attempts
- `retryOn` - Conditions that trigger fallback

### Step 3: Apply Configuration
```bash
kubectl apply -f provider-fallback.yaml
```

Wait for gateway to update:
```bash
kubectl wait pods --timeout=2m \
  -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -n envoy-gateway-system \
  --for=condition=Ready
```



### Step 4: Test Normal Operation

Setup port forward if not already:
```bash
export ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')

kubectl port-forward -n envoy-gateway-system svc/$ENVOY_SERVICE 8080:80
```

Test primary model:
```bash
export GATEWAY_URL="http://localhost:8080"

curl -H "Content-Type: application/json" \
  -d '{
        "model": "qwen-with-fallback",
        "messages": [
            {
                "role": "user",
                "content": "Explain quantum computing in detail."
            }
        ],
        "max_tokens": 150
    }' \
  $GATEWAY_URL/v1/chat/completions
```

**Expected**: Request succeeds via primary model (1.5b - more detailed response).

![Normal Operation](images/ticket2-normal-operation.png)
*Figure 6: Request successfully processed by primary model*

### Step 5: Test Fallback by Deleting Primary Isvc

Get primary pod:
```bash
kubectl get isvc -n default | grep qwen-primary
```

Delete primary isvc:
```bash
kubectl delete inferenceservice qwen-primary

```

Immediately test (while primary is down):
```bash
curl -H "Content-Type: application/json" \
  -d '{
        "model": "qwen-with-fallback",
        "messages": [
            {
                "role": "user",
                "content": "Explain quantum computing in detail."
            }
        ],
        "max_tokens": 150
    }' \
  $GATEWAY_URL/v1/chat/completions
```

**Expected Result**:
- Gateway attempts primary (fails - pod deleted)
- Automatically retries on fallback (priority 1 - secondary model)
- Request succeeds via fallback model (0.5b - simpler response)
- No client-side error

![Fallback Success](images/ticket2-fallback-success.png)
*Figure 8: Request successfully handled by fallback model*

### Step 6: Monitor Fallback Behavior

Watch logs to observe fallback in real-time:
```bash
kubectl logs -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  --tail=50 -f
```

Look for connection failures and retry messages showing:
- Initial attempt to primary backend
- Connection failure or timeout
- Automatic retry to secondary backend
- Successful response from fallback

![Fallback Logs](images/ticket2-fallback-logs.png)
*Figure 9: Gateway logs showing primary failure and successful fallback to secondary*



### Step 7: Test Multiple Requests During Recovery

Run continuous requests to observe the complete failover and recovery cycle:
```bash
for i in {1..20}; do
  echo "Request $i at $(date +%H:%M:%S)"
  curl -s -H "Content-Type: application/json" \
    -d '{"model": "qwen-with-fallback", "messages": [{"role": "user", "content": "Hi"}], "max_tokens": 30}' \
    $GATEWAY_URL/v1/chat/completions | jq -r '.choices[0].message.content // "ERROR"'
  sleep 2
done
```

**Expected Behavior**:
- Initially: Requests use fallback (primary down)
- After ~30-60s: Primary recovers, requests return to primary
- No request failures throughout



### Step 8: Reapply Primary Isvc For Return to Normal

Apply primary isvc and wait to be Ready
```bash
kubectl apply -f  provider-fallback.yaml
sleep 60
```

Wait for primary to be ready:
```bash
kubectl get pods -n default | grep qwen-primary
kubectl get isvc qwen-primary -n default
```


Test again:
```bash
curl -H "Content-Type: application/json" \
  -d '{
        "model": "qwen-with-fallback",
        "messages": [
            {
                "role": "user",
                "content": "Explain machine learning."
            }
        ],
        "max_tokens": 150
    }' \
  $GATEWAY_URL/v1/chat/completions
```

**Expected**: Back to primary model (better quality responses from 1.5b model).

---

## Troubleshooting

### Check Gateway Status
```bash
kubectl get gateway,aigatewayroute,aiservicebackend,backend -n default
kubectl describe gateway envoy-ai-gateway-basic -n default
```

### Check InferenceServices
```bash
kubectl get isvc -n default
kubectl describe isvc <name> -n default
```

### Check Pods
```bash
kubectl get pods -n default
kubectl logs -n default <pod-name>
```

### Check Gateway Logs
```bash
kubectl logs -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic -f
```

### Check Backend Connectivity
```bash
kubectl get backend -n default
kubectl describe backend <backend-name> -n default
```

### Verify Services
```bash
kubectl get svc -n default | grep predictor
```

### Common Issues

**Models not ready**: Wait longer for ollama to pull models (can take 5-10 minutes).

**Gateway pods not starting**: Check resources with `kubectl describe pod`.

**503 errors**: Verify backend services exist and are accessible.

**Fallback not triggering**: Check BackendTrafficPolicy and retry configuration.

---

## Summary

### Model Name Virtualization
- Clients use: `virtual-qwen-model`
- Gateway routes to: `qwen2.5:1.5b` (50%), `qwen2.5:0.5b` (30%), `qwen2.5:0.5b` (20%)
- Uses `weight` for traffic distribution across multiple backends
- Configuration via `modelNameOverride` in AIGatewayRoute

### Provider Fallback
- Primary: `qwen2.5:1.5b` (priority 0)
- Fallback: `qwen2.5:0.5b` (priority 1, weaker model)
- Uses `priority` for failover sequence
- Automatic retry on failure via BackendTrafficPolicy
- Test by deleting primary isvc - requests continue via fallback
- Zero downtime during recovery

