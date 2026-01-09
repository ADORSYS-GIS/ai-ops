# Testing Rate Limiting with Envoy AI Gateway

This guide provides a step-by-step walkthrough for testing request rate limiting using the Envoy AI Gateway. You'll start by setting up and testing the gateway **without rate limiting** to establish a baseline, then enable **Redis-backed rate limiting** to observe enforcement. Finally, you'll explore an alternative rate limiting approach using Limitador (via Kuadrant).

**Prerequisites:**

- A Kubernetes cluster (e.g., K3s) is installed and running. If not, see the setup instructions below.
- `kubectl` is installed and configured to access your cluster.
- Basic familiarity with Kubernetes manifests and `curl` for testing.

---

## 1. Environment Setup

Before configuring the gateway, ensure your environment has the necessary components installed. This includes K3s, Envoy Gateway, and the Envoy AI Gateway controller, which handle routing and AI-specific features like token counting.

### Install K3s

Install K3s using the official installation script:

```bash
curl -sfL https://get.k3s.io | sh -
```
Configure the `kubectl` client :

```bash
mkdir $HOME/.kube/ || echo "Directory is present already" && sudo cp -r /etc/rancher/k3s/k3s.yaml $HOME/.kube/config
```

Give require permissions :
```bash
sudo chown $(whoami):$(whoami) $HOME/.kube/config   
KUBECONFIG=$HOME/.kube/config
```

Verify K3s is running:

```bash
kubectl get nodes
```

### Install Envoy Gateway

```bash
helm upgrade -i eg oci://docker.io/envoyproxy/gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-gateway-system \
  --create-namespace \
  -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/manifests/envoy-gateway-values.yaml

kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```

### Install AI Gateway CRDs

```bash
helm upgrade -i aieg-crd oci://docker.io/envoyproxy/ai-gateway-crds-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace
```

Verify CRDs are installed:

```bash
kubectl get crd | grep aigateway
```

### Install AI Gateway Controller

```bash
helm upgrade -i aieg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace

kubectl wait --timeout=2m -n envoy-ai-gateway-system deployment/ai-gateway-controller --for=condition=Available
```

---

## 2. Configure the Gateway (Without Rate Limiting yet)

In this step, you'll deploy the base Envoy configuration and gateway resources to create a functional AI gateway. This setup allows requests to pass through without any rate limiting, so you can test basic functionality first.

## **Note:** Ensure the API key in [docs-manifest/envoy-configs/envoy-config.yaml](docs-manifest/envoy-configs/envoy-config.yaml) is valid for the backend service.

### Apply the Base Envoy Configuration

Apply the manifests that define the AI Gateway route, backend, security policy, and TLS settings. This sets up routing to an external AI service (e.g., OpenAI-compatible API) and enables API key authentication.

```bash
kubectl apply -f docs-manifest/envoy-configs/envoy-config.yaml
```

Verify resources created by the manifest (Gateway, HTTPRoute, ConfigMap, etc.):

```bash
kubectl get -f docs-manifest/envoy-configs/envoy-config.yaml
kubectl get gateway,httproute,configmap -n default || true
```

### Apply the Gateway Manifest

Apply the Gateway and GatewayClass resources to create an HTTP listener on port 80. This exposes the gateway for incoming requests.

```bash
kubectl apply -f docs-manifest/envoy-configs/envoy-gateway.yaml
```

---

## 3. Test Requests with curl

Now that the gateway is configured, test it by sending requests. This verifies that the gateway forwards requests to the backend AI service correctly.

### Port Forward the Gateway Service

Expose the Envoy service locally on port 8080. First, retrieve the service name dynamically, as it may vary.

```bash
export ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')

kubectl port-forward -n envoy-gateway-system svc/$ENVOY_SERVICE 8080:80 &
```

**Explanation:** This command finds the Envoy service associated with your gateway and forwards traffic from localhost:8080 to the service's port 80. Keep this running in a separate terminal.

### Set the Gateway URL

Define an environment variable for the local gateway URL to simplify commands.

```bash
export GATEWAY_URL="http://localhost:8080"
```

### Send a Test Request

Use `curl` to send a sample chat completion request. Include headers for user identification and model selection.

```bash
curl -v -H "Content-Type: application/json" \
  -H "x-user-id: user123" \
  -d '{
    "model": "gpt-5-mini",
    "messages": [
      {
        "role": "user",
        "content": "hi"
      }
    ]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

**Expected Behavior:** The request should succeed (HTTP 200) and return a response from the AI service. At this stage, there's no rate limiting, so multiple requests will all pass.

## 4. Enable Rate Limiting

To enforce rate limits, integrate Redis as the backend store for tracking request counts. This allows per-user limits based on headers like `x-user-id` and model-specific token usage.

### Deploy Redis

Apply the Redis StatefulSet and service manifests to set up a single-node Redis instance for rate limit storage.

```bash
kubectl apply -f docs-manifest/redis/redis-deployment.yaml
```

Wait for Redis pods to become ready and verify the service:

```bash
kubectl wait --for=condition=Ready pod --all -n redis-system --timeout=2m
kubectl get pods,svc -n redis-system
```

**Explanation:** This creates a Redis pod in the `redis-system` namespace with persistent storage. Wait for the pod to be ready before proceeding.

### Configure Redis as the Rate Limit Backend

Update the Envoy Gateway's configuration to use Redis for rate limiting.

- make sure `yq` command is install `sudo snap install yq -y` before.

```bash
kubectl get configmap envoy-gateway-config -n envoy-gateway-system -o yaml \
| yq '.data["envoy-gateway.yaml"] += "\nrateLimit:\n  backend:\n    type: Redis\n    redis:\n      url: redis.redis-system.svc.cluster.local:6379\n"' \
| kubectl apply -f -
```

Restart Envoy deployment so the new configmap is picked up and verify rollout:

```bash
kubectl rollout restart deployment/envoy-gateway -n envoy-gateway-system
kubectl rollout status deployment/envoy-gateway -n envoy-gateway-system --timeout=2m

# Verify the configmap contains the rateLimit section
kubectl get configmap envoy-gateway-config -n envoy-gateway-system -o yaml | yq '.data["envoy-gateway.yaml"]' -r | grep -A2 "rateLimit:" || true
```

**Explanation:** This patches the ConfigMap to enable global rate limiting with Redis as the datastore. The gateway will now track and enforce limits across requests.

### Apply the Rate Limiting Manifest

Apply the BackendTrafficPolicy that defines specific rate limit rules (e.g., token-based limits per user and model).

```bash
kubectl apply -f docs-manifest/envoy-configs/rate-limiting-envoy.yaml
```

Verify the policy is applied:

```bash
kubectl get backendtrafficpolicy -n default
```

**Explanation:** This policy enforces limits like 3 requests per minute for "gpt-5-mini" based on total tokens used, tracked via response metadata. Restart the Envoy deployment if needed for changes to take effect.

---

## 5. Test Rate Limiting

With rate limiting enabled, test that requests are throttled after exceeding limits.

### Set the Gateway URL (if not already set)

If the port-forward is still active, reuse the variable.

```bash
export GATEWAY_URL="http://localhost:8080"
```

### Send Test Requests

Send the same request multiple times to trigger the limit.

```bash
curl -v -H "Content-Type: application/json" \
  -H "x-user-id: user123" \
  -d '{
    "model": "gpt-5-mini",
    "messages": [
      {
        "role": "user",
        "content": "hi"
      }
    ]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

**Expected Behavior:** The first few requests (up to 3 per minute) should succeed. Subsequent requests should fail with an HTTP 429 (Too Many Requests) status, indicating rate limiting is active.

---

# Limitador Rate Limiting

As an alternative to Envoy's built-in rate limiting, use Limitador (via Kuadrant) for more flexible, policy-based limits. This integrates with the gateway via a RateLimitPolicy.

### Remove Previous Rate Limiting Policy

To avoid conflicts between Envoy and Limitador rate limiting, delete the Envoy BackendTrafficPolicy before proceeding.

```bash
kubectl delete -f docs-manifest/envoy-configs/rate-limiting-envoy.yaml
```

Verify it's removed:

```bash
kubectl get backendtrafficpolicy -n default
```

## OLM (Operator Lifecycle Manager) installed

Operator Lifecycle Manager (OLM) is a tool that helps manage Kubernetes applications called Operators.

OLM makes it easier to install, upgrade, and manage these Operators in a reliable and automated way

```bash
curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.28.0/install.sh | bash -s v0.28.0
```

Verify OLM is installed:

```bash
kubectl get pods -n olm
```

## Install Kuadrant Operator and CRDs

Install the Kuadrant operator using Helm, which provides Limitador for rate limiting.

```bash
helm repo add kuadrant https://kuadrant.io/helm-charts/
helm install kuadrant-operator kuadrant/kuadrant-operator
```

Wait for the operator to be ready:

```bash
kubectl wait --timeout=5m -n default deployment/kuadrant-operator-controller-manager --for=condition=Available
```

**Explanation:** This installs the operator.

## Acttivate kuadrant control plance
```bash
  kubectl apply -f - <<'EOF'
  apiVersion: kuadrant.io/v1beta1
  kind: Kuadrant
  metadata:
    name: kuadrant-sample
    namespace: default        
  spec: {}
EOF

```

```bash
kubectl wait --timeout=5m -n default deployment/limitador-limitador --for=condition=Available
```

**Explanation:** This activates the Kuadrant control plane, enabling Limitador for enforcing policies.

## Apply the RateLimitPolicy

Apply the policy that defines limits (e.g., 3 requests per minute per user).

```bash
kubectl apply -f docs-manifest/limitador/rate-limit-policy.yaml
```

Verify the policy is applied:

```bash
kubectl get ratelimitpolicy -n default
```

**Explanation:** This attaches the policy to the HTTPRoute `envoy-ai-gateway-basic-openai`, enforcing request-based limits.

## Test the Request

Send requests to verify limiting.

```bash
curl -v -H "Content-Type: application/json" \
  -H "x-user-id: user1" \
  -d '{
    "model": "gpt-5-mini",
    "messages": [
      {
        "role": "user",
        "content": "hi"
      }
    ]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

**Expected Behavior:** No more than 3 requests per minute per user. Exceeding this results in HTTP 429.

Good luck! If issues arise, refer to logs or the referenced docs.
