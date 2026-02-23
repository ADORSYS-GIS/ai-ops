## Issue Summary – Fireworks Image Generation via Envoy AI Gateway

### Description

While integrating Fireworks image generation into the Envoy AI Gateway, we discovered a **fundamental incompatibility** between Fireworks' image API and the OpenAI-style contract assumed by the gateway.

Fireworks **does not support** the standard OpenAI image endpoint:

```bash
POST /v1/images/generations
```

Instead, it requires a **model-specific, provider-defined path**:

```bash
POST /inference/v1/image_generation/<model-id>
# Example: POST /inference/v1/image_generation/playground-v2-5-1024px-aesthetic
```

### The Core Problem

Envoy AI Gateway (via [`AIGatewayRoute`](charts/models/templates/aigatewayroute.yaml:17)) does **not support request path rewriting**. The gateway is designed to forward requests as-is to the backend, making it impossible to translate OpenAI-compatible requests into Fireworks-specific endpoints at the gateway layer.

---

### Observed Behavior

#### Test 1: Standard OpenAI Image Request (Expected to Fail)

```bash
# Client request to gateway
curl -v \
  -H "Content-Type: application/json" \
  -H "x-user-id: user123" \
  -d '{
    "model": "playground-v2",
    "prompt": "a car",
    "size": "1024x1024"
  }' \
  http://<gateway.example.com>/v1/images/generations \
  --output game_controller.png
```

**Response:**
```json
{
  "error": {
    "message": "404 Path not found",
    "type": "invalid_request_error",
    "code": "404"
  }
}
```

#### Test 2: HTTPRoute with URL Rewrite (Workaround Attempt)

We attempted to use [`HTTPRoute`](httproute-image.yaml:17) with URL rewrite filters:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: playground-v2-image
spec:
  parentRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: ai-gateway
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /v1/images/generations
          headers:
            - type: Exact
              name: x-ai-eg-model
              value: playground-v2
      filters:
        - type: URLRewrite
          urlRewrite:
            path:
              type: ReplacePrefixMatch
              replacePrefixMatch: /inference/v1/image_generation/accounts/fireworks/models/playground-v2-5-1024px-aesthetic
      backendRefs:
        - group: gateway.envoyproxy.io
          kind: Backend
          name: fw-backend-01-svc
        - group: gateway.envoyproxy.io
          kind: Backend
          name: fw-backend-02-svc
```

**Issue:** While this rewrites the path, the [`BackendSecurityPolicy`](charts/models/templates/backendsecuritypolicy.yaml:4) cannot inject authentication for this route. The authentication injection only works with `AIGatewayRoute`.

#### Test 3: Client-Supplied API Key (Partial Success)

When the Fireworks API key is supplied by the client directly:

```bash
# Client request with their own Fireworks API key
curl -v \
  -H "Content-Type: application/json" \
  -H "x-user-id: user123" \
  -H "Authorization: Bearer $FIREWORKS_API_KEY" \
  -d '{
    "model": "playground-v2",
    "prompt": "a car",
    "size": "1024x1024"
  }' \
  http://<gateway.example.com>/v1/images/generations \
  --output game_controller.png
```

**Result:** This works, but exposes secrets to clients.

#### Test 4: BackendSecurityPolicy (Expected to Work, But Fails)

```bash
# Client request with their own Fireworks API key
curl -v \
  -H "Content-Type: application/json" \
  -H "x-user-id: user123" \
  -d '{
    "model": "playground-v2",
    "prompt": "a car",
    "size": "1024x1024"
  }' \
  http://<gateway.example.com>/v1/images/generations \
  --output game_controller.png
```

**Response:**
```json
{
  "error": {
    "message": "401 Unauthorized",
    "type": "invalid_request_error",
    "code": "401"
  }
}
```

This confirms that authentication injection and routing cannot be enforced consistently for Fireworks image generation.

---

### Root Cause Analysis

| Component | Expected Behavior | Actual Behavior |
|-----------|-------------------|-----------------|
| Fireworks Image API | `/inference/v1/image_generation/<model>` | Requires non-OpenAI path |
| AIGatewayRoute | Provider-agnostic routing | No path rewrite support |
| BackendSecurityPolicy | Inject API key seamlessly | Fails with 401 for image endpoints |
| HTTPRoute | Can rewrite URLs | Works but bypasses security policy |

The fundamental issues are:

1. **Fireworks image generation is not OpenAI-compatible at the routing level**
2. **Envoy AI Gateway cannot dynamically rewrite paths** when using `AIGatewayRoute`
3. **BackendSecurityPolicy assumes provider-agnostic paths** that don't match Fireworks' requirements
4. **This creates a mismatch** between gateway expectations and Fireworks requirements

---

### Impact Assessment

| Impact Area | Severity | Description |
|-------------|----------|-------------|
| **Secret Exposure** | 🔴 Critical | Secrets must be exposed to clients to make image generation work |
| **Token Accounting** | 🔴 High | Token accounting is bypassed when clients provide their own keys |
| **Rate Limiting** | 🟠 Medium | Per-user rate limiting is inconsistent |
| **API Consistency** | 🟠 Medium | Behavior differs between chat and image models |
| **Production Readiness** | 🔴 Critical | Overall setup becomes fragile and non-production-ready |

---

### Available Solutions

While the core incompatibility exists, this is a possible soultion to this :

#### Solution: Transformation Proxy (Recommended) 🎯

Deploy a lightweight microservice that:
- Accepts OpenAI-format requests at `/v1/images/generations`
- Transforms paths and body format for Fireworks
- Handles API key injection internally
- Returns OpenAI-compatible responses

```
Client → Gateway → Transformation Proxy → Fireworks API
         (routes)   (transforms + auth)
```

### Conclusion

The Fireworks image generation integration with Envoy AI Gateway is **not feasible** without additional infrastructure:

- ✅ Chat models work correctly via `AIGatewayRoute` + `BackendSecurityPolicy`
- ❌ Image models fail due to path incompatibility
- ❌ Workarounds compromise security (exposing API keys to clients)
- ❌ Token accounting and rate limiting are bypassed

**Recommendation:** This work has been deferred until either:
1. Envoy AI Gateway adds support for path rewriting in `AIGatewayRoute`
2. Fireworks adds support for OpenAI-compatible image endpoints
3. A dedicated adapter service is implemented

---

