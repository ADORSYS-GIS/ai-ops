# AI Gateway Observability - Quick Start Guide

Quick practical guide to enable metrics and tracing on an already deployed Envoy AI Gateway.

---

## Prerequisites

- Envoy AI Gateway already deployed
- `helm` access to the cluster
- `kubectl` configured with cluster access

---

## Step 1: Install Phoenix (Observability Backend)

```bash
# Install Phoenix for trace collection
helm install phoenix oci://registry-1.docker.io/arizephoenix/phoenix-helm \
  --namespace envoy-ai-gateway-system \
  --set auth.enableAuth=false \
  --set server.port=6006

# Wait for Phoenix to be ready
kubectl wait --timeout=5m -n envoy-ai-gateway-system \
  pods -l app.kubernetes.io/name=phoenix --for=condition=Ready
```

---

## Step 2: Enable Traces on AI Gateway

```bash
# Upgrade AI Gateway to send traces to Phoenix
helm upgrade ai-eg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --set "extProc.extraEnvVars[0].name=OTEL_EXPORTER_OTLP_ENDPOINT" \
  --set "extProc.extraEnvVars[0].value=http://phoenix-svc.envoy-ai-gateway-system:6006" \
  --set "extProc.extraEnvVars[1].name=OTEL_METRICS_EXPORTER" \
  --set "extProc.extraEnvVars[1].value=none"
```

---

## Step 3: (Optional) Enable Sensitive Data Redaction

Add these environment variables to hide sensitive content:

```bash
helm upgrade ai-eg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --set "extProc.extraEnvVars[0].name=OTEL_EXPORTER_OTLP_ENDPOINT" \
  --set "extProc.extraEnvVars[0].value=http://phoenix-svc.envoy-ai-gateway-system:6006" \
  --set "extProc.extraEnvVars[1].name=OTEL_METRICS_EXPORTER" \
  --set "extProc.extraEnvVars[1].value=none" \
  --set "extProc.extraEnvVars[2].name=OPENINFERENCE_HIDE_INPUTS" \
  --set "extProc.extraEnvVars[2].value=true" \
  --set "extProc.extraEnvVars[3].name=OPENINFERENCE_HIDE_OUTPUTS" \
  --set "extProc.extraEnvVars[3].value=true" \
  --set "extProc.extraEnvVars[4].name=OPENINFERENCE_HIDE_EMBEDDINGS_TEXT" \
  --set "extProc.extraEnvVars[4].value=true" \
  --set "extProc.extraEnvVars[5].name=OPENINFERENCE_HIDE_EMBEDDINGS_VECTORS" \
  --set "extProc.extraEnvVars[5].value=true"
```

### Redaction Reference

| Variable | What It Hides |
|----------|---------------|
| `OPENINFERENCE_HIDE_INPUTS` | User prompts to LLM |
| `OPENINFERENCE_HIDE_OUTPUTS` | LLM responses |
| `OPENINFERENCE_HIDE_EMBEDDINGS_TEXT` | Text sent to embedding models |
| `OPENINFERENCE_HIDE_EMBEDDINGS_VECTORS` | Vector output from embeddings |

---

## Step 4: (Optional) Session Tracking

Track multi-turn conversations by adding session ID to requests:

```bash
# Make a request with session ID to group related traces
curl -X POST http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-session-id: user-123-session-456" \
  -H "x-ai-eg-model: gemini-2.5-flash" \
  -d '{
    "model": "gemini-2.5-flash",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

| Header | Purpose |
|--------|---------|
| `x-session-id` | Groups related traces for multi-turn conversations |
| `x-correlation-id` | Links traces across services |

---

## Verification

### Check Phoenix is Receiving Traces

```bash
kubectl logs -n envoy-ai-gateway-system deployment/phoenix | grep "POST /v1/traces"
```

Expected output:
```
INFO:     10.42.0.19:44946 - "POST /v1/traces HTTP/1.1" 200 OK
```

### Access Phoenix UI

```bash
kubectl port-forward -n envoy-ai-gateway-system svc/phoenix-svc 6006:6006
```

Open http://localhost:6006 to view traces.

### Verify Environment Variables

```bash
# Get the envoy pod name
ENVOY_POD=$(kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic -o jsonpath='{.items[0].metadata.name}')

# Check OTEL configuration
kubectl get pod -n envoy-gateway-system $ENVOY_POD -o json | jq '.spec.containers[] | select(.name=="ai-gateway-extproc") | .env | from_entries'
```

---

## Rollback

If issues arise, downgrade to previous configuration:

```bash
helm rollback ai-eg --namespace envoy-ai-gateway-system
```

Or redeploy without observability:

```bash
helm upgrade ai-eg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --reuse-values \
  --set "extProc.extraEnvVars[0].name=OTEL_METRICS_EXPORTER" \
  --set "extProc.extraEnvVars[0].value=none"
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Traces not appearing | Check Phoenix pod is running: `kubectl get pods -n envoy-ai-gateway-system -l app.kubernetes.io/name=phoenix` |
| Connection refused | Verify OTEL endpoint matches Phoenix service: `http://phoenix-svc.envoy-ai-gateway-system:6006` |
| Metrics needed | Configure Prometheus separately (Phoenix only supports traces) |

---

## References

- [AI Gateway Observability Docs](https://aigateway.envoyproxy.io/docs/capabilities/observability/tracing)
- [Phoenix Documentation](https://arize.com/docs/phoenix)
