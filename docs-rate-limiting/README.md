# Testing Rate Limiting with Envoy AI Gateway

This guide provides a step-by-step walkthrough for testing request rate limiting using the Envoy AI Gateway. You'll start by setting up and testing the gateway **without rate limiting** to establish a baseline, then enable **Redis-backed rate limiting** to observe enforcement. Finally, you'll explore an alternative rate limiting approach using Limitador (via Kuadrant).

**Prerequisites:**

- A Kubernetes cluster (e.g., K3s) is installed and running. If not, follow the setup in [docs-info/setup.md](docs-info/setup.md).
- `kubectl` is installed and configured to access your cluster.
- Basic familiarity with Kubernetes manifests and `curl` for testing.

---

## 1. Run the Initial Setup

Before configuring the gateway, ensure your environment has the necessary components installed. This includes K3s, Envoy Gateway, and the Envoy AI Gateway controller, which handle routing and AI-specific features like token counting.

Follow the detailed installation steps in [docs-info/setup.md](docs-info/setup.md). This document covers installing K3s, Envoy Gateway, AI Gateway CRDs, and the controller. Once complete, verify that the deployments are running (e.g., check pods in `envoy-gateway-system` and `envoy-ai-gateway-system` namespaces).

---

## 2. Configure the Gateway (Without Rate Limiting)

In this step, you'll deploy the base Envoy configuration and gateway resources to create a functional AI gateway. This setup allows requests to pass through without any rate limiting, so you can test basic functionality first.

### Apply the Base Envoy Configuration

Apply the manifests that define the AI Gateway route, backend, security policy, and TLS settings. This sets up routing to an external AI service (e.g., OpenAI-compatible API) and enables API key authentication.

```bash
kubectl apply -f docs-manifest/envoy-configs/envoy-config.yaml
```

### Apply the Gateway Manifest

Apply the Gateway and GatewayClass resources to create an HTTP listener on port 80. This exposes the gateway for incoming requests.

```bash
kubectl apply -f docs-manifest/envoy-configs/envoy-gateway.yaml
```

**Explanation:** These manifests create a Gateway named `envoy-ai-gateway-basic` in the `default` namespace, which routes requests based on headers like `x-ai-eg-model` (e.g., for models like "gpt-5-mini"). Without rate limiting, all valid requests should succeed.

---

## 3. Test Requests with curl

Now that the gateway is configured, test it by sending requests. This verifies that the gateway forwards requests to the backend AI service correctly.

### Port Forward the Gateway Service

Expose the Envoy service locally on port 8080. First, retrieve the service name dynamically, as it may vary.

```bash
export ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')

kubectl port-forward -n envoy-gateway-system svc/$ENVOY_SERVICE 8080:80
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

**Note:** Ensure the API key in [docs-manifest/envoy-configs/envoy-config.yaml](docs-manifest/envoy-configs/envoy-config.yaml) is valid for the backend service.
---

## 4. Enable Rate Limiting

To enforce rate limits, integrate Redis as the backend store for tracking request counts. This allows per-user limits based on headers like `x-user-id` and model-specific token usage.

### Deploy Redis

Apply the Redis StatefulSet and service manifests to set up a single-node Redis instance for rate limit storage.

```bash
kubectl apply -f ./docs-manifest/redis/redis-deployment.yaml
```

**Explanation:** This creates a Redis pod in the `redis-system` namespace with persistent storage. Wait for the pod to be ready before proceeding.

### Configure Redis as the Rate Limit Backend

Update the Envoy Gateway's configuration to use Redis for rate limiting.
+ make sure `yq` command is install `sudo apt install yq -y` before.

```bash
kubectl get configmap envoy-gateway-config -n envoy-gateway-system -o yaml \
| yq '.data["envoy-gateway.yaml"] += "\nrateLimit:\n  backend:\n    type: Redis\n    redis:\n      url: redis.redis-system.svc.cluster.local:6379\n"' \
| kubectl apply -f -
```

**Explanation:** This patches the ConfigMap to enable global rate limiting with Redis as the datastore. The gateway will now track and enforce limits across requests.

### Apply the Rate Limiting Manifest

Apply the BackendTrafficPolicy that defines specific rate limit rules (e.g., token-based limits per user and model).

```bash
kubectl apply -f ./docs-manifest/envoy-rate-limiting/rate-limiting-envoy.yaml
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

**Note:** Limits reset based on the window (e.g., per minute). For advanced rules, see [docs-info/advance-rl-envoy.md](docs-info/advance-rl-envoy.md).

---

# Limitador Rate Limiting

As an alternative to Envoy's built-in rate limiting, use Limitador (via Kuadrant) for more flexible, policy-based limits. This integrates with the gateway via a RateLimitPolicy.
## OLM (Operator Lifecycle Manager) installed
```bash
curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.28.0/install.sh | bash -s v0.28.0   
```

## Install Kuadrant Operator and CRDs

Install the Kuadrant operator using Helm, which provides Limitador for rate limiting.

```bash
helm repo add kuadrant https://kuadrant.io/helm-charts/
helm install kuadrant-operator kuadrant/kuadrant-operator
```

**Warning:** Official Kuadrant docs may have issues with the operator. Check pod logs in the `kuadrant-system` namespace. If problems occur, apply the provided manifests instead:

```bash
cd manifests/
kubectl apply -f .
```

**Explanation:** This installs the operator and activates the Kuadrant control plane, enabling Limitador for enforcing policies.

## Apply the RateLimitPolicy

Apply the policy that defines limits (e.g., 3 requests per minute per user).

```bash
kubectl apply -f docs-manifest/limitador/rate-limit-policy.yaml
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
