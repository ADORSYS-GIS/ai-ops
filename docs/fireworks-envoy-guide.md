# FireworksAI Integration with Envoy AI Gateway

## Overview

This guide demonstrates how to integrate FireworksAI's API with Envoy AI Gateway, enabling you to route requests to FireworksAI's models through a unified gateway interface. By the end of this documentation, you'll have:

✅ Envoy AI Gateway deployed and configured

✅ FireworksAI backend integrated with multiple model endpoints

✅ Support for chat completions, embeddings, and vision capabilities

✅ Model mapping from friendly names to FireworksAI model identifiers

✅ Validated API endpoints matching OpenAI's schema

## Prerequisites

- Kubernetes cluster (k3d or k3s)
- kubectl CLI tool installed
- Helm 3.x installed
- Docker (if using k3d)
- A valid FireworksAI API key ([Get one here](https://fireworks.ai/))

## Environment Setup

You can choose between two approaches for your Kubernetes cluster:

### Option A: Using k3d (Docker-based)

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
# Create cluster with 1 server and 2 agents
k3d cluster create ai \
  --servers 1 \
  --agents 2 \
  --image rancher/k3s:v1.32.0-k3s1

# Verify cluster
kubectl cluster-info
kubectl get nodes
```

#### k3d Cluster Management Commands
```bash
# Stop cluster
k3d cluster stop ai

# Start cluster
k3d cluster start ai

# Delete cluster
k3d cluster delete ai

# List clusters
k3d cluster list
```

### Option B: Using k3s (VM/Bare Metal)

#### Install K3s
```bash
curl -sfL https://get.k3s.io | sh -
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chmod 644 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG="$HOME/.kube/config"' >> "$HOME/.${0##*/}rc"
```

---

### Common Setup (Both Options)

#### Install Helm
```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

#### Install K9s (Optional but Recommended)
```bash
curl -sS https://webinstall.dev/k9s | sh
```

## Install Envoy Gateway

Install Envoy Gateway with AI Gateway support:

```bash
helm upgrade -i eg oci://docker.io/envoyproxy/gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-gateway-system \
  --create-namespace \
  -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/manifests/envoy-gateway-values.yaml

kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

## Install AI Gateway Components

### Install AI Gateway CRDs
```bash
helm upgrade -i aieg-crd oci://docker.io/envoyproxy/ai-gateway-crds-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace
```

### Install AI Gateway Controller
```bash
helm upgrade -i aieg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace

kubectl wait --timeout=2m -n envoy-ai-gateway-system deployment/ai-gateway-controller --for=condition=Available
```

### Verify Installation
```bash
kubectl get pods -n envoy-ai-gateway-system
```

Expected output:
```text
NAME                                     READY   STATUS    RESTARTS   AGE
ai-gateway-controller-6d4c4f7787-bmtvc   1/1     Running   0          30s
```

## Deploy Basic Gateway Configuration

Deploy the basic AI Gateway setup:

```bash
kubectl apply -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/examples/basic/basic.yaml
```

Wait for the Gateway pods to be ready:

```bash
kubectl wait pods --timeout=2m \
  -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -n envoy-gateway-system \
  --for=condition=Ready
```

Verify the service is created:

```bash
kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic
```

Expected output:
```text
NAME                                            TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
envoy-default-envoy-ai-gateway-basic-21a9f8f8   LoadBalancer   10.43.104.101   <pending>     80:31444/TCP   71s
```

## Configure FireworksAI Backend

Create a file named `fireworks.yaml` with the following content:

```yaml
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIGatewayRoute
metadata:
  name: envoy-ai-gateway-fireworks
  namespace: default
spec:
  parentRefs:
    - name: envoy-ai-gateway-basic
      kind: Gateway
      group: gateway.networking.k8s.io
  llmRequestCosts:
    - metadataKey: prompt_tokens
      type: InputToken
    - metadataKey: completion_tokens
      type: OutputToken
    - metadataKey: total_tokens
      type: TotalToken
  rules:
    - matches:
        - headers:
            - type: Exact
              name: x-ai-eg-model
              value: qwen-embed
      backendRefs:
        - name: envoy-ai-gateway-fireworks
          modelNameOverride: accounts/fireworks/models/qwen3-embedding-8b
    - matches:
        - headers:
            - type: Exact
              name: x-ai-eg-model
              value: qwen-thinking
      backendRefs:
        - name: envoy-ai-gateway-fireworks
          modelNameOverride: accounts/fireworks/models/qwen3-vl-30b-a3b-thinking
    - matches:
        - headers:
            - type: Exact
              name: x-ai-eg-model
              value: qwen-instruct
      backendRefs:
        - name: envoy-ai-gateway-fireworks
          modelNameOverride: accounts/fireworks/models/qwen3-vl-235b-a22b-instruct
    - matches:
        - headers:
            - type: Exact
              name: x-ai-eg-model
              value: gpt-5
      backendRefs:
        - name: envoy-ai-gateway-fireworks
---
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: AIServiceBackend
metadata:
  name: envoy-ai-gateway-fireworks
  namespace: default
spec:
  schema:
    name: OpenAI
    prefix: /inference/v1
  backendRef:
    name: envoy-ai-gateway-fireworks
    kind: Backend
    group: gateway.envoyproxy.io
---
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: BackendSecurityPolicy
metadata:
  name: envoy-ai-gateway-fireworks-apikey
  namespace: default
spec:
  targetRefs:
    - group: aigateway.envoyproxy.io
      kind: AIServiceBackend
      name: envoy-ai-gateway-fireworks
  type: APIKey
  apiKey:
    secretRef:
      name: envoy-ai-gateway-fireworks-apikey
      namespace: default
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata:
  name: envoy-ai-gateway-fireworks
  namespace: default
spec:
  endpoints:
    - fqdn:
        hostname: api.fireworks.ai
        port: 443
---
apiVersion: gateway.networking.k8s.io/v1alpha3
kind: BackendTLSPolicy
metadata:
  name: envoy-ai-gateway-fireworks-tls
  namespace: default
spec:
  targetRefs:
    - group: "gateway.envoyproxy.io"
      kind: Backend
      name: envoy-ai-gateway-fireworks
  validation:
    wellKnownCACertificates: "System"
    hostname: api.fireworks.ai
---
apiVersion: v1
kind: Secret
metadata:
  name: envoy-ai-gateway-fireworks-apikey
  namespace: default
type: Opaque
stringData:
  apiKey: fw_YOUR_FIREWORKS_API_KEY_HERE  # Replace with your actual API key
```

**Important**: Replace `fw_YOUR_FIREWORKS_API_KEY_HERE` with your actual FireworksAI API key.

Apply the configuration:

```bash
kubectl apply -f fireworks.yaml
```

## Set Up Port Forwarding

In a terminal window, set up port forwarding to access the gateway:

```bash
export GATEWAY_URL="http://localhost:8080"
export ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')

kubectl port-forward -n envoy-gateway-system svc/$ENVOY_SERVICE 8080:80
```

This terminal will remain blocked while port-forwarding is active. Open a new terminal for testing.

## Testing the Integration

### Test Basic Endpoint (Mock Backend)

First, verify the basic setup with the test upstream:

```bash
curl -H "Content-Type: application/json" \
  -d '{
    "model": "some-cool-self-hosted-model",
    "messages": [
      {
        "role": "system",
        "content": "Hi."
      }
    ]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

Expected response:
```json
{"choices":[{"message":{"role":"assistant", "content":"I am the master of my fate, I am the captain of my soul."}}]}
```

### Test Chat Completions (qwen-instruct)

```bash
curl -v -H "Content-Type: application/json" \
  -H "x-user-id: user123" \
  -d '{
    "model": "qwen-instruct",
    "messages": [
      {
        "role": "user",
        "content": "Hello!"
      }
    ]
  }' \
  $GATEWAY_URL/v1/chat/completions | jq
```

Expected response (excerpt):
```json
{
  "id": "9508df2d-129c-403f-97a5-9319bb857925",
  "object": "chat.completion",
  "model": "accounts/fireworks/models/qwen3-vl-235b-a22b-instruct",
  "choices": [
    {
      "message": {
        "role": "assistant",
        "content": "Hello! 😊  \nHow can I help you today?..."
      },
      "finish_reason": "stop"
    }
  ],
  "usage": {
    "prompt_tokens": 10,
    "total_tokens": 46,
    "completion_tokens": 36
  }
}
```

### Test Reasoning Model (qwen-thinking)

```bash
curl -v -H "Content-Type: application/json" \
  -H "x-user-id: user123" \
  -d '{
    "model": "qwen-thinking",
    "messages": [
      {
        "role": "user",
        "content": "Hello!"
      }
    ]
  }' \
  $GATEWAY_URL/v1/chat/completions | jq
```

This model includes thinking/reasoning in its response.

### Test Embeddings (qwen-embed)

```bash
curl -v -H "Content-Type: application/json" \
  -H "x-user-id: user123" \
  -d '{
    "model": "qwen-embed",
    "input": "The quick brown fox jumped over the lazy dog"
  }' \
  $GATEWAY_URL/v1/embeddings | jq
```

Expected response (excerpt):
```json
{
  "data": [
    {
      "index": 0,
      "embedding": [0.99609375, 1.0625, 2.46875, ...],
      "object": "embedding"
    }
  ],
  "model": "accounts/fireworks/models/qwen3-embedding-8b",
  "usage": {
    "prompt_tokens": 11,
    "total_tokens": 11
  }
}
```

### Test Completions (qwen-instruct)

```bash
curl -v \
  -H "Content-Type: application/json" \
  -H "x-user-id: user123" \
  -d '{
        "model": "qwen-instruct",
        "prompt": "Hello!"
      }' \
  $GATEWAY_URL/v1/completions | jq
```

Expected response (excerpt):
```json
{
  "id": "bbc08d65-69f9-4c23-a5af-2d2a59d42aa0",
  "object": "text_completion",
  "created": 1768319392,
  "model": "accounts/fireworks/models/qwen3-vl-235b-a22b-instruct",
  "choices": [
    {
      "index": 0,
      "text": " I'm interested in learning more about the different types of clouds and how they form",
      "logprobs": null,
      "finish_reason": "length"
    }
  ],
  "usage": {
    "prompt_tokens": 2,
    "total_tokens": 18,
    "completion_tokens": 16,
    "prompt_tokens_details": {
      "cached_tokens": 0
    }
  }
}
```

### Test Vision Capabilities (qwen-thinking with image)

```bash
curl -v -H "Content-Type: application/json" \
  -H "x-user-id: user123" \
  -d '{
    "model": "qwen-thinking",
    "messages": [
      {
        "role": "user",
        "content": [
          {
            "type": "text",
            "text": "Can you describe this image?"
          },
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
  $GATEWAY_URL/v1/chat/completions | jq
```

The model will analyze the image and provide a detailed description.

### List Available Models

```bash
curl -v $GATEWAY_URL/v1/models | jq
```

Expected response:
```json
{
  "data": [
    {
      "id": "some-cool-self-hosted-model",
      "object": "model",
      "owned_by": "Envoy AI Gateway"
    },
    {
      "id": "qwen-embed",
      "object": "model",
      "owned_by": "Envoy AI Gateway"
    },
    {
      "id": "qwen-thinking",
      "object": "model",
      "owned_by": "Envoy AI Gateway"
    },
    {
      "id": "qwen-instruct",
      "object": "model",
      "owned_by": "Envoy AI Gateway"
    }
  ],
  "object": "list"
}
```

## Model Mapping Reference

| Friendly Name | FireworksAI Model ID | Use Case |
|--------------|---------------------|----------|
| `qwen-instruct` | `accounts/fireworks/models/qwen3-vl-235b-a22b-instruct` | Chat completions, general conversation |
| `qwen-thinking` | `accounts/fireworks/models/qwen3-vl-30b-a3b-thinking` | Reasoning tasks, vision analysis |
| `qwen-embed` | `accounts/fireworks/models/qwen3-embedding-8b` | Text embeddings |
| `gpt-5` | Maps to FireworksAI backend | Custom model mapping |

## Supported Endpoints

### ✅ `/v1/chat/completions`
- Standard OpenAI-compatible chat completions
- Supports text and vision inputs
- Model routing via `model` parameter

### ✅ `/v1/embeddings`
- Generate text embeddings
- Uses `qwen-embed` model
- Requires `input` field (not `messages`)

### ✅ `/v1/completions`
- Standard OpenAI-compatible completions
- Supports text generation with prompt
- Model routing via `model` parameter

## Important Notes

### Request Schema Requirements

1. **Chat Completions**: Must use `messages` array format
   ```json
   {
     "model": "qwen-instruct",
     "messages": [{"role": "user", "content": "Hello"}]
   }
   ```

2. **Embeddings**: Must use `input` field (not `messages`)
   ```json
   {
     "model": "qwen-embed",
     "input": "Text to embed"
   }
   ```

3. **Completions**: Must use `prompt` field
   ```json
   {
     "model": "qwen-instruct",
     "prompt": "Hello!"
   }
   ```

4. **Vision**: Use content array with `text` and `image_url` types
   ```json
   {
     "model": "qwen-thinking",
     "messages": [{
       "role": "user",
       "content": [
         {"type": "text", "text": "Describe this"},
         {"type": "image_url", "image_url": {"url": "https://..."}}
       ]
     }]
   }
   ```

### Image URL Requirements

- Must use `https://` protocol (not `file://`)
- Must be publicly accessible
- Supported formats: JPEG, PNG, PPM, GIF, TIFF, BMP
- Share links (e.g., Google Drive, Gemini) may not work directly

## Troubleshooting

### 404 Not Found Error
```json
{
  "error": {
    "message": "Path not found: /chat/completions",
    "code": "NOT_FOUND"
  }
}
```
**Solution**: Ensure `fireworks.yaml` is applied correctly and the route configuration is active.

### 401 Unauthorized Error
```json
{
  "detail": "Your session has expired or the token is invalid."
}
```
**Solution**: Verify your FireworksAI API key in the Secret and reapply `fireworks.yaml`.

### Model Not Found Error
```json
{
  "error": {
    "message": "Model not found, inaccessible, and/or not deployed",
    "code": "NOT_FOUND"
  }
}
```
**Solution**: Check that the model name in your request matches one defined in the AIGatewayRoute rules.

### Image Download Failed
```json
{
  "error": {
    "message": "Failed to download the image... UnsupportedProtocol"
  }
}
```
**Solution**: Use `https://` URLs only. Local files and share links are not supported.

## Cleanup

To remove all resources:

```bash
# Delete FireworksAI configuration
kubectl delete -f fireworks.yaml

# Delete basic gateway setup
kubectl delete -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/examples/basic/basic.yaml

# Uninstall AI Gateway
helm uninstall aieg -n envoy-ai-gateway-system
helm uninstall aieg-crd -n envoy-ai-gateway-system

# Uninstall Envoy Gateway
helm uninstall eg -n envoy-gateway-system

# Delete namespaces
kubectl delete namespace envoy-ai-gateway-system
kubectl delete namespace envoy-gateway-system

# For k3d: Delete cluster
k3d cluster delete ai
```

## References

- [Envoy AI Gateway Documentation](https://aigateway.envoyproxy.io/)
- [FireworksAI API Documentation](https://docs.fireworks.ai/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)
- [Envoy AI Gateway GitHub](https://github.com/envoyproxy/ai-gateway)
- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)

## Next Steps

- Add rate limiting with `RateLimitPolicy`
- Configure observability with Phoenix or OpenTelemetry
- Set up multiple backend providers with failover
- Implement custom model routing rules
- Add authentication and authorization layers