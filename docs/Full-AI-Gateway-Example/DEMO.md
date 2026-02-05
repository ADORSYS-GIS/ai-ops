 ## Full AI Gateway Example with Auth, Fallback, and Virtual Models Guide

 This guide provides a complete,  AI Gateway example demonstrating authentication, model fallback, rate limiting and virtual model abstraction.

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
sudo apt upgrade
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
echo "export KUBECONFIG=$(k3d kubeconfig write aiops)" >> "$HOME/.${0##*/}rc"

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
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace
```

  **Configure AI Gateway with OpenTelemetry**
```sh
helm install aieg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --set "extProc.extraEnvVars[0].name=OTEL_EXPORTER_OTLP_ENDPOINT" \
  --set "extProc.extraEnvVars[0].value=http://phoenix-svc.envoy-ai-gateway-system.svc.cluster.local:6006" \
  --set "extProc.extraEnvVars[1].name=OTEL_METRICS_EXPORTER" \
  --set "extProc.extraEnvVars[1].value=none"
# OTEL_SERVICE_NAME defaults to "ai-gateway" if not set
# OTEL_METRICS_EXPORTER=none because Phoenix only supports traces, not metrics
```

**Install Envoy Gateway with Rate Limiting Configured**
```bash
helm upgrade -i eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.6.0 \
  --namespace envoy-gateway-system \
  --create-namespace \
  -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/manifests/envoy-gateway-values.yaml \
  -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/examples/token_ratelimit/envoy-gateway-values-addon.yaml 

kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

## Testing 

**Create secret from your service account key file **
In our case our service account file name is `kivoyo.json`

```bash
# Create secret from your service account key file
kubectl create secret generic envoy-ai-gateway-basic-gcp-service-account-key-file \
  --from-file=service_account.json=./kivoyo.json \
  -n default

# Verify secret creation
kubectl get secret envoy-ai-gateway-basic-gcp-service-account-key-file -n default

# Validate secret content
kubectl get secret envoy-ai-gateway-basic-gcp-service-account-key-file -n default \
  -o jsonpath='{.data.service_account\.json}' | base64 -d | jq .
```

**Deploy Redis**

```bash 
kubectl apply -f redis-deployment.yaml
# wait for pods to be ready
kubectl wait --for=condition=Ready pod --all -n redis-system --timeout=2m
kubectl get pods,svc -n redis-system
```
**Apply all Configurations**

*Don't forget to update the values of project id and region in the gcp_vertex.yaml file. For our case we use `kivoyo` as PROJECT_ID and `us-central1` as REGION*

```bash
kubectl apply -f '*.yaml'
# Check AIServiceBackend status
kubectl get aiservicebackend -n default -o wide

# Check BackendSecurityPolicy
kubectl describe backendsecuritypolicy -n default 

# Check AIGatewayRoute
kubectl describe aigatewayroute  -n default 
```
**Configure Port Forwarding**

```bash
 # Get the Envoy service name
export ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')

# Port forward to access the gateway
kubectl port-forward -n envoy-gateway-system svc/$ENVOY_SERVICE 8080:80
```

**Sample Requests for Testing Model Virtualization, Fallback, Rate Limiting...**
```bash
# Set the gateway URL
export GATEWAY_URL="http://localhost:8080"
```
**Play around and experience**
```bash
curl -v -H "Content-Type: application/json" \
  -d '{                                             
    "model": "smart-llm",                           
    "messages": [               
      {"role": "user", "content": "What is artificial intelligence?"}
    ]                                                               
  }' \
  $GATEWAY_URL/v1/chat/completions
```
```bash
curl -v -H "Content-Type: application/json" \
  -d '{                                             
    "model": "gemini",                           
    "messages": [               
      {"role": "user", "content": "What is artificial intelligence?"}
    ]                                                               
  }' \
  $GATEWAY_URL/v1/chat/completions
```

```bash
curl -v \
  -H "Content-Type: application/json" \
  -H "x-user-id: user123" \
  -d '{
    "model": "smart-llm",
    "messages": [
      {
        "role": "user",
        "content": [
          { "type": "text", "text": "Can you describe this image?" },
          {
            "type": "image_url",
            "image_url": {
              "url": "https://images.unsplash.com/photo-1582538885592-e70a5d7ab3d3"
            }
          }
        ]
      }
    ]
  }' \
  "$GATEWAY_URL/v1/chat/completions" | jq

```
```bash
curl -v \
  -H "Content-Type: application/json" \
  -H "x-user-id: user123" \
  -d '{
    "model": "gemini",
    "messages": [
      {
        "role": "user",
        "content": "Hello!"
      }
    ]
  }' \
  "$GATEWAY_URL/v1/chat/completions"
```
## Observability
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
kubectl port-forward  --address 0.0.0.0 -n envoy-ai-gateway-system svc/phoenix-svc 6006:6006
```
Then open http://localhost:6006 in your browser to explore the traces.

Run as many requests as you wish and notice the changes in the phoenix UI

## Test Authorization with Authorino

You will have to follow Authorino Guide [from here](./Authorino/authorino.md).

## References

- [Architecture Diagram](./architecture-digram.drawio.svg)
- [Phoenix Observability](../phoenix-observability/README.md)
- [GCP Vertex AI Integration](../GCP-Vertex-AI-Integration/README.md)
- [Rate Limiting](../docs-rate-limiting/README.md)
- [Fireworks Guide](../fireworks-envoy-guide.md)
- [Model VirtualiZation & Fallback](../model-virtualization-provider-fallback.md)
- [Envoy Authorino Guide](../Envoy-authorino-authentication.md)

