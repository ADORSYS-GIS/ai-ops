
# AI Gateway Observability with Phoenix and Kivoyo Backend
## Overview

This guide walks through setting up [observability](https://docs.honeycomb.io/get-started/basics/observability/introduction/) for Envoy AI Gateway using Phoenix for tracing, specifically for monitoring traffic to your Kivoyo OpenAI-compatible backend. By the end of this documentation, you'll have:

    ✅ Phoenix installed and running alongside your Kivoyo setup

    ✅ AI Gateway configured to send OpenTelemetry traces to Phoenix

    ✅ Validation that Kivoyo API calls are being traced correctly

    ✅ Access to Phoenix UI to visualize Kivoyo request patterns, latencies, and errors
   
## Environment Setup

You can choose between two approaches for your Kubernetes cluster:

### Option A: Using Multipass VM

#### Create VM
```bash
multipass launch --name aiops --cpus 2 --mem 4G --disk 20G
multipass shell aiops
```
### Update and Upgrade system
```sh
sudo apt update 
sudo apt ugrade
```
#### Install K3s
```bash
curl -sfL https://get.k3s.io | sh -
mkdir ~/.kube
sudo cp -r /etc/rancher/k3s/k3s.yaml ~/.kube/config 
sudo chmod 644 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG="$HOME/.kube/config"' >> "$HOME/.${0##*/}rc"

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
**Install Phoenix for LLM observability**
```sh
# Install Phoenix using PostgreSQL storage.
helm install phoenix oci://registry-1.docker.io/arizephoenix/phoenix-helm \
  --namespace envoy-ai-gateway-system \
  --create-namespace \
  --set auth.enableAuth=false \
  --set server.port=6006
  ```
**Install AI Gateway CRDs**
```bash
helm upgrade -i aieg-crd oci://docker.io/envoyproxy/ai-gateway-crds-helm \
  --version v0.4.0 \
  --namespace envoy-ai-gateway-system \
  --create-namespace
```

  **Configure AI Gateway with OpenTelemetry**
```sh
helm install aieg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v0.4.0 \
  --namespace envoy-ai-gateway-system \
  --set "extProc.extraEnvVars[0].name=OTEL_EXPORTER_OTLP_ENDPOINT" \
  --set "extProc.extraEnvVars[0].value=http://phoenix-svc.envoy-ai-gateway-system.svc.cluster.local:6006" \
  --set "extProc.extraEnvVars[1].name=OTEL_METRICS_EXPORTER" \
  --set "extProc.extraEnvVars[1].value=none"
# OTEL_SERVICE_NAME defaults to "ai-gateway" if not set
# OTEL_METRICS_EXPORTER=none because Phoenix only supports traces, not metrics
```

**Install Envoy Gateway**
```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
    --version v1.6.0 \
    --namespace envoy-gateway-system \
    --create-namespace \
    -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/v0.4.0/manifests/envoy-gateway-values.yaml

kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```
**Verify Installation**
```bash
kubectl get pods -n envoy-ai-gateway-system
```
You should see all pods running
```text
NAME                                     READY   STATUS    RESTARTS   AGE
ai-gateway-controller-6f4cd954d9-h7vdv   1/1     Running   0          2m
phoenix-8f546998b-ztwzq                  1/1     Running   0          2m28s
phoenix-postgresql-0                     1/1     Running   0          2m28s
```
Let's deploy a basic AI Gateway setup:
```sh
kubectl apply -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/examples/basic/basic.yaml
```
Wait for the Gateway pod to be ready:
```sh
kubectl wait pods --timeout=2m \
  -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -n envoy-gateway-system \
  --for=condition=Ready
  ```
**Deploy kivoyo**

Replace the <YOUR_KIVOYO_LITELLM_API_KEY_HERE> in the last line of this file with a valid litellm API key from kivoyo
```sh
cat <<EOF | kubectl apply -f -
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIGatewayRoute
metadata:
  name: envoy-ai-gateway-basic-openai
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
              value: gemini-2.5-flash
      backendRefs:
        - name: envoy-ai-gateway-basic-openai
---
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIServiceBackend
metadata:
  name: envoy-ai-gateway-basic-openai
  namespace: default
spec:
  schema:
    name: OpenAI
  backendRef:
    name: envoy-ai-gateway-basic-openai
    kind: Backend
    group: gateway.envoyproxy.io
---
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: BackendSecurityPolicy
metadata:
  name: envoy-ai-gateway-basic-openai-apikey
  namespace: default
spec:
  targetRefs:
    - group: aigateway.envoyproxy.io
      kind: AIServiceBackend
      name: envoy-ai-gateway-basic-openai
  type: APIKey
  apiKey:
    secretRef:
      name: envoy-ai-gateway-basic-openai-apikey
      namespace: default
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata:
  name: envoy-ai-gateway-basic-openai
  namespace: default
spec:
  endpoints:
    - fqdn:
        hostname: api.ai.kivoyo.com
        port: 443
---
apiVersion: gateway.networking.k8s.io/v1alpha3
kind: BackendTLSPolicy
metadata:
  name: envoy-ai-gateway-basic-openai-tls
  namespace: default
spec:
  targetRefs:
    - group: "gateway.envoyproxy.io"
      kind: Backend
      name: envoy-ai-gateway-basic-openai
  validation:
    wellKnownCACertificates: "System"
    hostname: api.ai.kivoyo.com
---
apiVersion: v1
kind: Secret
metadata:
  name: envoy-ai-gateway-basic-openai-apikey
  namespace: default
type: Opaque
stringData:
  apiKey: <YOUR_KIVOYO_API_KEY_HERE>
EOF
```

**Check if the ext_proc filter is being inserted:**
For k3s
```sh
kubectl logs -n envoy-ai-gateway-system deployment/ai-gateway-controller --tail=50 | grep "inserting AI Gateway extproc"
```
For k3d 
```sh
kubectl logs -n envoy-ai-gateway-system deployment/ai-gateway-controller \
| grep "inserting AI Gateway extproc"
```
If you see output like inserting AI Gateway extproc filter into listener, the fix worked.

**Then verify OTEL env vars are in the sidecar:**
For k3s
```sh
ENVOY_POD=$(kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic -o jsonpath='{.items[0].metadata.name}')
kubectl get pod -n envoy-gateway-system $ENVOY_POD -o json | jq '.spec.initContainers[] | select(.name=="ai-gateway-extproc") | .env'
```
For k3d
```sh
ENVOY_POD=$(kubectl get pods -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')

kubectl get pod -n envoy-gateway-system "$ENVOY_POD" -o json \
| jq '.spec.containers[] | select(.name=="ai-gateway-extproc") | .env'
```
You should see OTEL_EXPORTER_OTLP_ENDPOINT in the output.

Set the gateway URL:
```sh
export GATEWAY_URL="http://localhost:8080"
```
Then set up port forwarding (this will block the terminal):
```sh
export ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')

kubectl port-forward -n envoy-gateway-system svc/$ENVOY_SERVICE 8080:80
```
**Test Kivoyo**
```sh
curl -i -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [{"role": "user", "content": "Hello Kivoyo"}]
  }'
  ```
  It should return 200 OK with some model response

**Check Phoenix is receiving traces**
```sh
kubectl logs -n envoy-ai-gateway-system deployment/phoenix | grep "POST /v1/traces"
```
You should get 
```text
kubectl logs -n envoy-ai-gateway-system deployment/phoenix | grep "POST /v1/traces"
INFO:     10.42.0.19:44946 - "POST /v1/traces HTTP/1.1" 200 OK
```
**Access Phoenix UI**
Port-forward to access the Phoenix dashboard:
```sh
kubectl port-forward -n envoy-ai-gateway-system svc/phoenix-svc 6006:6006
```
Then open http://localhost:6006 in your browser to explore the traces.

Run as many requests as you wish and notice the changes in the phoenix UI

**References**
- [AI-Gateway-docs](https://aigateway.envoyproxy.io/docs/capabilities/observability/tracing)

- [Phoenix-docs](https://arize.com/docs/phoenix)

- [what is observability? - honeycomb](https://docs.honeycomb.io/get-started/basics/observability/introduction/)