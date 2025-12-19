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

### Create VM
```bash
multipass launch --name aiops --cpus 8 --mem 20G --disk 50G
multipass shell aiops
```

### Install K3s
```bash
curl -sfL https://get.k3s.io | sh -
mkdir ~/.kube
sudo cp -r /etc/rancher/k3s/k3s.yaml ~/.kube/config 
sudo chmod 644 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
```

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
```bash
helm upgrade -i eg oci://docker.io/envoyproxy/gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-gateway-system \
  --create-namespace \
  -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/manifests/envoy-gateway-values.yaml

kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available

helm upgrade -i aieg-crd oci://docker.io/envoyproxy/ai-gateway-crds-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace

helm upgrade -i aieg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace

kubectl wait --timeout=2m -n envoy-ai-gateway-system deployment/ai-gateway-controller --for=condition=Available
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
kubectl apply -f primary-model.yaml
kubectl apply -f secondary-model.yaml
kubectl apply -f tertiary-model.yaml
```

Monitor deployment:
```bash
kubectl get pods -n default
kubectl get isvc -n default -w
```

Wait until all show `READY=True`.

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
- `x-ai-eg-model: virtual-qwen-model` - Client uses this virtual name
- `modelNameOverride` - Gateway translates to actual model names
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
**Monitor  Behavior**

Watch logs to observe model virtualization:
```bash
kubectl logs -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  --tail=50 -f
```


---

## Ticket 2: Provider Fallback

**Goal**: Configure primary model with automatic fallback. Test by deleting primary pod to verify failover to weaker fallback model.

### Step 1: Create Model Files

**File: `primary-fallback-model.yaml`**
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

**File: `fallback-model.yaml`**
```yaml
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: qwen-fallback
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

**Note**: Fallback uses smaller 0.5b model (weaker but faster/cheaper).

### Step 2: Deploy Models
```bash
kubectl apply -f primary-fallback-model.yaml
kubectl apply -f fallback-model.yaml
```

Monitor:
```bash
kubectl get pods -n default
kubectl get isvc -n default -w
```

### Step 3: Create Fallback Gateway Configuration

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
        - name: envoy-ai-gateway-qwen-primary
          modelNameOverride: qwen2.5:1.5b
          priority: 0
        - name: envoy-ai-gateway-qwen-fallback
          modelNameOverride: qwen2.5:0.5b
          priority: 1
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
  name: envoy-ai-gateway-qwen-fallback
  namespace: default
spec:
  schema:
    name: OpenAI
  backendRef:
    name: envoy-ai-gateway-qwen-fallback
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
  name: envoy-ai-gateway-qwen-fallback
  namespace: default
spec:
  endpoints:
    - fqdn:
        hostname: qwen-fallback-predictor-00001.default.svc.cluster.local
        port: 80
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: envoy-ai-gateway-fallback-policy
  namespace: default
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: envoy-ai-gateway-fallback
  retry:
    numAttemptsPerPriority: 1
    numRetries: 5
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
        - 401
        - 403
      triggers:
        - connect-failure
        - retriable-status-codes
```

**Key Configuration**:
- `priority: 0` - Primary model tried first
- `priority: 1` - Fallback model tried if primary fails
- `numAttemptsPerPriority: 1` - One attempt per backend
- `retryOn` - Conditions that trigger fallback

### Step 4: Apply Configuration
```bash
kubectl apply -f gateway-setup.yaml  # If not already applied
kubectl apply -f provider-fallback.yaml
```

Wait for gateway:
```bash
kubectl wait pods --timeout=2m \
  -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -n envoy-gateway-system \
  --for=condition=Ready
```

### Step 5: Test Normal Operation

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

### Step 6: Test Fallback by Deleting Primary Pod

Get primary pod:
```bash
kubectl get pods -n default -l serving.kserve.io/inferenceservice=qwen-primary-fb
```

Delete primary pod:
```bash
kubectl delete pod -n default -l serving.kserve.io/inferenceservice=qwen-primary-fb
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
- Automatically retries on fallback (priority 1)
- Request succeeds via fallback model (0.5b - simpler response)
- No client-side error

### Step 7: Monitor Fallback Behavior

Watch logs to observe fallback:
```bash
kubectl logs -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  --tail=50 -f
```

Look for connection failures and retry messages.

Check pod status:
```bash
kubectl get pods -n default -w
```

Primary pod will restart automatically (KServe behavior).

### Step 8: Test Multiple Requests During Recovery

Run continuous requests:
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

### Step 9: Verify Return to Normal

Wait for primary to be ready:
```bash
kubectl get pods -n default -l serving.kserve.io/inferenceservice=qwen-primary-fb -w
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

**Expected**: Back to primary model (better quality responses).

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
- Test by deleting primary pod - requests continue via fallback
- Zero downtime during recovery