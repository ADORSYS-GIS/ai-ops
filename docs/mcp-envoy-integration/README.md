# MCP Envoy Integration

This guide provides step-by-step instructions for integrating MCP (Model Context Protocol) with Envoy Gateway.

## Prerequisites

Before you begin, ensure you have the following tools installed:
- kubectl
- helm
- Access to a Kubernetes cluster

## Installation

### 1. Configure kubectl

Copy the Kubernetes configuration file from Rancher K3s:

```bash
sudo cp -r /etc/rancher/k3s/k3s.yaml ~/.kube/config
```

### 2. Install Envoy Gateway

Deploy Envoy Gateway using Helm:

```bash
helm upgrade -i eg oci://docker.io/envoyproxy/gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-gateway-system \
  --create-namespace \
  -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/manifests/envoy-gateway-values.yaml
```

Wait for the deployment to be ready:

```bash
kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

### 3. Install AI Gateway CRDs

Deploy the AI Gateway Custom Resource Definitions:

```bash
helm upgrade -i aieg-crd oci://docker.io/envoyproxy/ai-gateway-crds-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace
```

### 4. Install AI Gateway

Deploy the AI Gateway controller:

```bash
helm upgrade -i aieg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace
```

Wait for the controller to be ready:

```bash
kubectl wait --timeout=2m -n envoy-ai-gateway-system deployment/ai-gateway-controller --for=condition=Available
```

## Configuration

### 1. Create Backend Resource

Create a Backend resource for your MCP server (e.g., GitHub Copilot):

```bash
cat <<EOF | kubectl apply -f -
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: Backend
metadata:
  name: github-mcp-backend
  namespace: default
spec:
  endpoints:
    - fqdn:
        hostname: api.githubcopilot.com
        port: 443
---
apiVersion: gateway.networking.k8s.io/v1alpha3
kind: BackendTLSPolicy
metadata:
  name: github-mcp-tls
  namespace: default
spec:
  targetRefs:
    - group: "gateway.envoyproxy.io"
      kind: Backend
      name: github-mcp-backend  # Must match your Backend name
  validation:
    wellKnownCACertificates: "System"
    hostname: api.githubcopilot.com   
---
apiVersion: v1
kind: Secret
metadata:
  name: github-token
  namespace: default
type: Opaque
stringData:
  apiKey: <Your-Github-PAT> # Replace with your github PAT key.
---
EOF
```

### 2. Create MCP Route

Create an MCP Route to expose your MCP server through the gateway:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: aigateway.envoyproxy.io/v1alpha1
kind: MCPRoute
metadata:
  name: mcp-route
  namespace: default
spec:
  parentRefs:
    - name: envoy-ai-gateway-basic
      kind: Gateway
      group: gateway.networking.k8s.io
  path: "/mcp"  # Clients call http(s)://<gateway-address>/mcp
  backendRefs:
    - name: github-mcp-backend
      kind: Backend
      group: gateway.envoyproxy.io
      path: "/mcp/x/issues/readonly"
      securityPolicy:
        apiKey:
          secretRef:
            name: github-token
EOF
```

## Verification

### Test the MCP Endpoint

Verify the MCP server is accessible by sending an initialize request:

```bash
curl -X POST http://localhost:8080/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2025-03-26",
      "clientInfo": {
        "name": "test-client",
        "version": "1.0.0"
      }
    }
  }' | jq
```

A successful response should include server capabilities:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "capabilities": {
      "completions": {},
      "logging": {},
      "prompts": {
        "listChanged": true
      },
      "resources": {
        "listChanged": true,
        "subscribe": true
      },
      "tools": {
        "listChanged": true
      }
    },
    "protocolVersion": "2025-06-18",
    "serverInfo": {
      "name": "envoy-ai-gateway",
      "version": "dev"
    }
  }
}
```

## AI Agent 

### Install Goose AI Agent
```bash
curl -fsSL https://github.com/block/goose/releases/download/stable/download_cli.sh | bash   
```

```bash
# Optional if not resolved automatically
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc   
```

## Configure Goose AI Provider
Run the following command :
```bash 
# Configure Custom AI provider (kivoyo)
goose configure
# http streamable endpoint is localhost:8080
```
After the config, run `goose configure` and select you custom AI provider you to enable it.
*  If issue occur refers to : (Goose Custom AI Provider)[https://block.github.io/goose/docs/getting-started/providers/]

### Configure MCP Integration
Run the following command :
```bash
goose configure
```
Configure the MCP integration by specifying the `localhost:8080/mcp` path for goose to be aware to the github tool access. 
Add this extension description :
```md
You have access to a GitHub MCP server that enables you to interact with GitHub repositories using natural language.  This includes creating and managing repositories, opening pull requests, reviewing code, triaging issues, and retrieving repository data. The server uses your authenticated GitHub account (via a Personal Access Token) to perform actions securely. You can use this tool to automate workflows, review code changes, and manage project infrastructure directly through conversation
``` 

* If issue occur refers to : (Goose Add extension)[https://block.github.io/goose/docs/getting-started/using-extensions/]

## Troubleshooting

If you encounter issues during installation or configuration:

1. Check pod status in the envoy-gateway-system namespace:
   ```bash
   kubectl get pods -n envoy-gateway-system
   ```

2. View logs for the AI Gateway controller:
   ```bash
   kubectl logs -n envoy-ai-gateway-system deployment/ai-gateway-controller
   ```

3. Verify all resources are properly created:
   ```bash
   kubectl get backend,mcproute,secret -n default
   ```

## Cleanup

To remove all resources created during this installation:

```bash
# Delete MCP Route
kubectl delete -f mcproute/mcp-route -n default

# Uninstall AI Gateway
helm uninstall aieg -n envoy-ai-gateway-system
helm uninstall aieg-crd -n envoy-ai-gateway-system

# Uninstall Envoy Gateway
helm uninstall eg -n envoy-gateway-system
```

