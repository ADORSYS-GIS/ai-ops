# Testing Rate Limiting with Envoy AI Gateway

This guide explains how to test request rate limiting using the Envoy AI Gateway. You will first run the gateway **without rate limiting**, then enable **Redis-backed rate limiting** and verify the behavior.

## 1. Run the Initial Setup

Follow the setup instructions in the documentation:

- 📄 [docs-info/setup.md](docs-info/setup.md)

## 2. Configure the Gateway (Without Rate Limiting)

Apply the base Envoy configuration and gateway manifests:

```bash
kubectl apply -f docs-manifest/envoy-configs/envoy-config.yaml
kubectl apply -f docs-manifest/envoy-configs/envoy-gateway.yaml
```

## 3. Test Requests with curl

### Port Forward the Gateway Service

Retrieve the Envoy service name and expose it locally:

```bash
export ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')

kubectl port-forward -n envoy-gateway-system svc/$ENVOY_SERVICE 8080:80
```

### Set the Gateway URL

```bash
export GATEWAY_URL="http://localhost:8080"
```

### Send a Test Request

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

At this stage, requests should succeed without any rate limiting.

## 4. Enable Rate Limiting

### Deploy Redis

Apply the Redis deployment manifest:

```bash
kubectl apply -f ./docs-manifest/redis/redis-deployment.yaml
```

### Configure Redis as the Rate Limit Backend

Patch the Envoy Gateway configuration to enable Redis-based rate limiting:

```bash
kubectl patch configmap envoy-gateway-config -n envoy-gateway-system \
  --type merge \
  -p '{"data": {"envoy-gateway.yaml": "rateLimit:\n  backend:\n    type: Redis\n    redis:\n      url: redis.redis-system.svc.cluster.local:6379\n"}}'
```

### Apply the Rate Limiting Manifest

```bash
kubectl apply -f ./docs-manifest/envoy-rate-limiting/rate-limiting.yaml
```

## 5. Test Rate Limiting

### Set the Gateway URL (if not already set)

```bash
export GATEWAY_URL="http://localhost:8080"
```

### Send Test Requests

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

🔴 Expected behavior: Sending the request more than three times should result in a failure due to rate limiting.


# Limitador Rate Limiting
## Install Kuadrant Operator and CRDS
```bash
helm repo add kuadrant https://kuadrant.io/helm-charts/
helm install kuadrant-operator kuadrant/kuadrant-operator 
```

Warning : The official docs is having an issue with the kuadrant operator -- check the logs of the pods to ensure. So to fix it we apply these manifest :

```bash
cd manifests/
kubectl apply -f .
```
+ This activate the kuadrant control plane at the same time.

## Apply the RatelimitPolicy
```bash
kubectl apply -f docs-manifest/limitador/rate-limit-policy.yaml
```
## Test the request
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
+ It should not work more than 3 times.

Good luck !