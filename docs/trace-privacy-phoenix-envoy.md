# OpenInference Trace Privacy Configuration for Envoy AI Gateway

## Overview

OpenInference provides environment variables to control the observability level of your AI tracing, allowing you to hide sensitive information for security or privacy reasons. This guide explains how to configure these settings in the Envoy AI Gateway context.

**Reference**: [OpenInference Configuration Specification](https://arize-ai.github.io/openinference/spec/configuration.html)

## Official Defaults

By default, OpenInference shows all telemetry data in Phoenix:

| Variable | Effect | Default Value |
|----------|--------|--------------|
| `OPENINFERENCE_HIDE_INPUTS` | Hides all input data and messages | `false` |
| `OPENINFERENCE_HIDE_OUTPUTS` | Hides all output data and messages | `false` |
| `OPENINFERENCE_HIDE_INPUT_MESSAGES` | Hides input messages specifically | `false` |
| `OPENINFERENCE_HIDE_OUTPUT_MESSAGES` | Hides output messages specifically | `false` |
| `OPENINFERENCE_HIDE_INPUT_TEXT` | Hides text from input messages | `false` |
| `OPENINFERENCE_HIDE_OUTPUT_TEXT` | Hides text from output messages | `false` |
| `OPENINFERENCE_HIDE_INPUT_IMAGES` | Hides images from input messages | `false` |
| `OPENINFERENCE_HIDE_EMBEDDING_VECTORS` | Hides returned embedding vectors | `false` |
| `OPENINFERENCE_HIDE_LLM_INVOCATION_PARAMETERS` | Hides LLM parameters (temp, max_tokens, etc.) | `false` |
| `OPENINFERENCE_HIDE_LLM_PROMPTS` | Hides LLM prompt templates | `false` |
| `OPENINFERENCE_BASE64_IMAGE_MAX_LENGTH` | Max base64 image size in chars | `32000` |

## Recommended Envoy AI Gateway Configuration

Our `values.yaml` uses this privacy-conscious setup:

```yaml
- name: OPENINFERENCE_HIDE_INPUTS
  value: "false"
- name: OPENINFERENCE_HIDE_OUTPUTS
  value: "false"
- name: OPENINFERENCE_HIDE_INPUT_MESSAGES
  value: "false"
- name: OPENINFERENCE_HIDE_OUTPUT_MESSAGES
  value: "false"
- name: OPENINFERENCE_HIDE_INPUT_TEXT
  value: "true"      # 🔒 Hide sensitive text
- name: OPENINFERENCE_HIDE_OUTPUT_TEXT
  value: "true"      # 🔒 Hide sensitive text
- name: OPENINFERENCE_HIDE_INPUT_IMAGES
  value: "true"      # 🔒 Hide image data
- name: OPENINFERENCE_HIDE_EMBEDDING_VECTORS
  value: "false"
- name: OPENINFERENCE_HIDE_LLM_INVOCATION_PARAMETERS
  value: "false"
- name: OPENINFERENCE_HIDE_LLM_PROMPTS
  value: "false"
```

### What Gets Shown in Phoenix

**✅ Visible:**
- Input/output message structure and metadata
- LLM parameters (temperature, max_tokens, model name)
- System prompts and user prompts
- Embedding vectors for analysis
- Token usage and costs

**❌ Hidden:**
- Actual text content (replaced with `"__REDACTED__"`)
- Image data

## Configuration Variables

Replace these placeholders with your actual values:

| Placeholder | Description | Example Value |
|-------------|-------------|---------------|
| `${NAMESPACE}` | Kubernetes namespace for Envoy AI Gateway | `envoy-ai-gateway-system` |
| `${GATEWAY_NAME}` | Name of your Envoy Gateway | `envoy-ai-gateway-basic` |
| `${DEPLOYMENT_NAME}` | Name of the Envoy deployment | `envoy-default-envoy-ai-gateway-basic-21a9f8f8` |
| `${HELM_RELEASE_NAME}` | Helm release name for AI Gateway | `aieg` |

## Configuration Methods

### 1. Helm Values (Recommended)

Add to your `values.yaml`:

```yaml
extProc:
  extraEnvVars:
    - name: OPENINFERENCE_HIDE_INPUTS
      value: "false"
    # ... other variables
```

Apply changes:
```bash
helm upgrade aieg oci://docker.io/envoyproxy/ai-gateway-helm \
  --namespace ${NAMESPACE} \
  -f values.yaml

kubectl rollout restart deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE}
```

## Security Trade-off Examples

### Maximum Privacy (Production)
```yaml
All variables: "true"  # Everything hidden
```

### Balanced (Recommended)
```yaml
# Structure visible, content hidden
OPENINFERENCE_HIDE_INPUTS: "false"
OPENINFERENCE_HIDE_OUTPUTS: "false"
OPENINFERENCE_HIDE_INPUT_TEXT: "true"
OPENINFERENCE_HIDE_OUTPUT_TEXT: "true"
# ... keep others at "false"
```

### Full Debug (Development)
```yaml
All variables: "false"  # Everything visible (official defaults)
```

## Verification

Check current configuration:

```bash
ENVOY_POD=$(kubectl get pods -n ${NAMESPACE} \
  -l gateway.envoyproxy.io/owning-gateway-name=${GATEWAY_NAME} \
  -o jsonpath='{.items[0].metadata.name}')

kubectl get pod -n ${NAMESPACE} "$ENVOY_POD" -o jsonpath='{
.spec.containers[?(@.name=="ai-gateway-extproc")].env}'
```

## Troubleshooting

**Issue:** Changes not applied
**Solution:** `kubectl rollout restart deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE}`

**Issue:** Variables still showing defaults
**Solution:** Check quotes: `value: "false"` not `value: false`

## Related Documentation

- [OpenInference Configuration Spec](https://arize-ai.github.io/openinference/spec/configuration.html)
- [Phoenix Masking Docs](https://arize.com/docs/phoenix/tracing/how-to-tracing/advanced/masking-span-attributes)
- [Envoy GenAI Distributed Tracing](https://aigateway.envoyproxy.io/docs/capabilities/observability/tracing)