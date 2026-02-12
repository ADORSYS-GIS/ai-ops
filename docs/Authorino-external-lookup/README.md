# External API Key Validation with Authorino

This guide demonstrates how to validate client API keys using an external validation service with Authorino and Envoy AI Gateway.

## Architecture

```
Client (X-CLIENT-KEY) 
  ↓
Envoy AI Gateway 
  ↓
Authorino (ext_authz)
  ↓
External Validation Service (validates key)
  ↓
Allow/Deny Decision
  ↓
Envoy AI Gateway
  ↓
Provider
```

**Key Principle**: Client API keys are validated by calling an external HTTP service. Authorino acts as the authorization layer, but the validation logic lives externally.

## Naming Convention

Resource names are provider-agnostic and role-based:

- `ai-gateway-class`: GatewayClass
- `ai-gateway`: Gateway
- `ai-gateway-proxy`: EnvoyProxy
- `ai-model-route`: AIGatewayRoute
- `ai-llm-service`: AIServiceBackend
- `ai-llm-upstream`: Backend
- `ai-llm-upstream-tls`: BackendTLSPolicy
- `ai-llm-provider-apikey`: BackendSecurityPolicy + Secret
- `gateway-external-auth`: SecurityPolicy

---
## Prerequistes
- Kubernetes cluster (k3d)
- kubectl CLI tool installed
- Helm 3.x installed
- Docker (if using k3d)
- A valid FireworksAI API key ([Get one here](https://fireworks.ai/))
- Envoy AI Gateway installed
- Authorino operator installed

## SetUp

```bash
# Deploy Authorino
kubectl apply -f authorino.yaml

# Create namespace
kubectl apply -f namespace.yaml

# Deploy Gateway Config
kubectl apply -f basic.yaml

# Deploy Model backend (in the model-config.yaml file update the secret with the right API key)
kubectl apply -f model-config.yaml

# Apply SecurityPolicy
kubectl apply -f security-policy.yaml
```


## Option 1: Python Backend (Recommended)

### Advantages
- Returns JSON responses (easier to parse)
- Better logging and debugging
- Easy to extend with database integration


**authconfig.yaml**
```yaml
apiVersion: authorino.kuadrant.io/v1beta3
kind: AuthConfig
metadata:
  name: external-apikey-auth
  namespace: auth
spec:
  hosts:
    - "*"
  # Step 1: Extract API key from incoming request
  authentication:
    "client-key":
      plain:
        expression: context.request.http.headers["x-client-key"]

  # Step 2: Call mock backend to validate the key
  metadata:
    "api-key-check":
      http:
        url: "http://api-key-mock-python.auth.svc.cluster.local:8080/validate"
        method: GET
        headers:
          "X-API-Key":
            selector: context.request.http.headers.x-client-key

  # Step 2: Check if backend returned valid: true
  authorization:
    "check-backend-response":
      opa:
        rego: |
          allow {
            input.auth.metadata["api-key-check"].valid == true
          }
          "X-API-Key":
            selector: context.request.http.headers.x-client-key

```

### Deployment Steps

```bash
cd python-mock-backend

# 1. Build and load image
docker build -t api-key-validator:latest .
k3d image import api-key-validator:latest -c <cluster-name>

# 2. Deploy validator
kubectl apply -f deployment.yaml

# 3. Deploy AuthConfig
kubectl apply -f authconfig.yaml

```

---

## Option 2: Nginx Backend (Lightweight)

### Advantages
- Very lightweight (no Python runtime)
- Fast and efficient
- Simple configuration

### Files Required

**authconfig.yaml**
```yaml
apiVersion: authorino.kuadrant.io/v1beta3
kind: AuthConfig
metadata:
  name: external-apikey-auth
  namespace: auth
  labels:
    authorino-portal: "true"
spec:
  hosts:
    - "*"
  # Step 1: Extract API key from incoming request
  authentication:
    "client-key":
      plain:
        expression: context.request.http.headers["x-client-key"]

  # Step 2: Call mock backend to validate the key
  metadata:
    "api-key-check":
      http:
        url: "http://api-key-mock.auth.svc.cluster.local/validate"
        method: GET
        headers:
          "X-API-Key":
            selector: context.request.http.headers.x-client-key

  # Step 2: Check if backend returned valid: true
  authorization:
    "check-backend-response":
      opa:
        rego: |
          allow {
            input.auth.metadata["api-key-check"].valid == true
          }

```

### Deployment Steps

```bash
# 1. Deploy nginx validator
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml

# 2. Deploy AuthConfig
kubectl apply -f authconfig.yaml

```

---

## Testing

### Valid Key (Should Succeed)
```bash
curl -v \           
  -H "Host: localhost" \               
  -H "x-client-key: client-key-456" \   
  -H "Content-Type: application/json" \    
  -d '{
    "model": "accounts/fireworks/models/qwen3-vl-30b-a3b-thinking",
    "messages": [
      { "role": "user", "content": "hi" }
    ]                  
  }' \                     
  $GATEWAY_URL/v1/chat/completions

```
Expected: `200 OK` with model response

### Invalid Key (Should Fail)
```bash
curl -v \           
  -H "Host: localhost" \               
  -H "x-client-key: invalid-key" \   
  -H "Content-Type: application/json" \    
  -d '{
    "model": "accounts/fireworks/models/qwen3-vl-30b-a3b-thinking",
    "messages": [
      { "role": "user", "content": "hi" }
    ]                  
  }' \                     
  $GATEWAY_URL/v1/chat/completions

```
Expected: `403 Forbidden`

### Missing Key (Should Fail)
```bash
curl -v \
  -H "Host: localhost" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "accounts/fireworks/models/qwen3-vl-30b-a3b-thinking",
    "messages": [
      { "role": "user", "content": "hi" }
    ]
  }' \
  $GATEWAY_URL/v1/chat/completions

```
Expected: `401 Unauthorized`

---

## Debugging

### Check Authorino Logs
```bash
kubectl logs <authorino pod> -n auth | jq  
```
Look for:
- `"incoming authorization request"`
- `"outgoing authorization response"`
- `"authorized": true/false`

### Check Envoy Logs

**Envoy:**
```bash
kubectl logs -n envoy-gateway-system <envoy=pod> | jq
```

### Test Validator Directly
```bash
kubectl run test -n auth --rm -it --image=curlimages/curl -- sh

# Valid key
# nginx backend
curl -v -H "X-API-Key: client-key-123" \
  http://api-key-mock.auth.svc.cluster.local/validate

# Python backend
curl -v -H "X-API-Key: client-key-123" \
  http://api-key-mock.auth.svc.cluster.local:8080/validate


# Invalid key  
# Nginx backend
curl -v -H "X-API-Key: bad-key" \
  http://api-key-mock.auth.svc.cluster.local/validate

# Python backedn
curl -v -H "X-API-Key: wrong-key" \
  http://api-key-mock.auth.svc.cluster.local:8080/validate

```

---

## Adding More Keys

### Python Backend
Edit `app.py`:
```python
VALID_KEYS = {
    "client-key-123": {"user_id": "user-001"},
    "new-key-789": {"user_id": "user-003"}  # Add here
}
```
Rebuild and redeploy.

### Nginx Backend
Edit `configmap.yaml`:
```nginx
map $http_x_api_key $api_key_valid {
  default 0;
  "client-key-123" 1;
  "new-key-789" 1;  # Add here
}
```
Apply and restart:
```bash
kubectl apply -f configmap.yaml
kubectl rollout restart <deployment> -n auth
```

---

## Production Considerations

1. **Replace hardcoded keys** with database lookups
2. **Add caching** to reduce latency (Redis)
3. **Implement rate limiting** per API key
4. **Add metrics** (Prometheus)
5. **Enable TLS** for validator service
6. **Scale replicas** for high availability (3+)
7. **Add monitoring** and alerting

---

## Troubleshooting

### All Requests Return 403

**Cause**: Authorino not receiving requests  
**Fix**: Check SecurityPolicy is applied and targeting correct Gateway

### All Requests Pass (Even Invalid Keys)

**Cause**: AuthConfig not active or host mismatch  
**Fix**: Check `kubectl get authconfig -n auth` shows `ready: true`

### 500 Internal Server Error

**Cause**: Validator service unreachable  
**Fix**: Verify validator pod is running and service exists

### "unknown field" Error in AuthConfig

**Cause**: Using wrong API syntax for v1beta3  
**Fix**: Use `expression:` not `selector:` or `valueFrom:` in metadata headers
