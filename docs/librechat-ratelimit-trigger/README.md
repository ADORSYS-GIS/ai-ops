# Reproducing LibreChat Rate-Limit Behavior with Envoy AI Gateway

This document explains how to reproduce and observe the rate-limiting behavior between **LibreChat** and the **Envoy AI Gateway**, and why rate limits may not appear to be enforced in the LibreChat UI under certain conditions.

The test is performed locally using **k3s** (or any local Kubernetes cluster) and a custom LibreChat provider pointing directly to the Envoy proxy.

---

## Goal

- Validate that rate limiting based on `X-User-ID` is correctly enforced by Envoy.
- Demonstrate that LibreChat UI timeouts can mask rate-limit errors (e.g. `429` / `409`) that are otherwise visible when using direct `curl` requests.
- Provide a deterministic way to reproduce the behavior and reach the same conclusion.

---

## Prerequisites

- A local Kubernetes cluster (k3s, kind, minikube, etc.)
- Helm installed
- Envoy AI Gateway deployed with:
  - Rate limiting enabled
  - One or more OpenAI-compatible models behind the gateway
- Access to the Envoy gateway endpoint:

```
http://converse-llm.camer.digital/v1/chat/completions
```

---

## LibreChat Setup (Custom Provider)

LibreChat will be configured to use a **custom OpenAI-compatible endpoint** pointing directly to the Envoy gateway.

Reference documentation:  
https://www.librechat.ai/docs/quick_start/custom_endpoints

---

## Step 1: Create Kubernetes Secrets

Create a secret to store LibreChat credentials.

**`secret-envs.yaml`**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: librechat-credentials-env
type: Opaque
stringData:
  CREDS_KEY: 9e95d9894da7e68dd69c0046caf5343c8b1e80c89609b5a1e40e6568b5b23ce6
  CREDS_IV: ac028c86ba23f4cd48165e0ca9f2c683
  JWT_SECRET: 16f8c0ef4a5d391b26034086c628469d3f9f497f08163ab9b40137092f2909ef
  JWT_REFRESH_SECRET: eaa5191f2914e30b9387fd84e254e4ba6fc51b4654968a9b0803b456a54b8418
```

Apply the secret:

```bash
kubectl apply -f secret-envs.yaml
```

---

## Step 2: Configure values.yaml

Ensure your `values.yaml` contains the following configuration.

Key points:

- Enable the custom endpoint
- Forward X-User-ID and X-User-Email headers
- Point baseURL to the Envoy gateway

```yaml
librechat:
  configEnv:
    CREDS_KEY: 9e95d9894da7e68dd69c0046caf5343c8b1e80c89609b5a1e40e6568b5b23ce6
    CREDS_IV: ac028c86ba23f4cd48165e0ca9f2c683
    JWT_SECRET: 16f8c0ef4a5d391b26034086c628469d3f9f497f08163ab9b40137092f2909ef
    JWT_REFRESH_SECRET: eaa5191f2914e30b9387fd84e254e4ba6fc51b4654968a9b0803b456a54b8418
    ALLOW_REGISTRATION: "true"
    ALLOW_EMAIL_LOGIN: "true"
    DEBUG_LOGGING: "true"
    DEBUG_CONSOLE: "true"
    DEBUG_OPENAI: "true"
    ENDPOINTS: "custom"
    existingSecretName: "librechat-credentials-env"

  imageVolume:
    enabled: false
    size: 10G

  configYamlContent: |
    version: 1.2.8
    cache: true
    endpoints:
      custom:
        - name: "GPT-CUSTOM-PROVIDER"
          apiKey: "REPLACE_YOUR_API_KEY"
          baseURL: "http://converse-llm.camer.digital/v1"
          models:
            default: ["gpt-4-1"]
            fetch: true
          titleConvo: true
          titleModel: "current_model"
          modelDisplayLabel: "GPT-CUSTOM-PROVIDER"
          headers:
            X-User-ID: "{{LIBRECHAT_USER_ID}}"
            X-User-Email: "{{LIBRECHAT_USER_EMAIL}}"
            Authorization: "APIKEY REPLACE_YOUR_API_KEY"
```

---

## Step 3: Install LibreChat via Helm

```bash
helm repo add librechat https://danny-avila.github.io/LibreChat/
helm install librechat librechat/librechat -f values.yaml
```

---

## Step 4: Expose the Service

By default, LibreChat uses ClusterIP. For local testing, expose it externally.

Example:

```yaml
service:
  type: LoadBalancer
  port: 3080
```

Alternatively, use an Ingress if available.

---

## Step 5: Access the LibreChat UI

Open the UI in your browser:

```
http://<external-ip>:3080
```

1. Register a user
2. Confirm the custom provider is available
3. Send a test prompt to verify basic connectivity

Once confirmed, proceed to the rate-limit test.

---

## Step 6: Identify the LibreChat User ID

Get the LibreChat pod name:

```bash
kubectl get pods
```

Example output:

```
librechat-librechat-57b4f56689-zfw2t   1/1   Running
```

Extract the user ID from the logs:

```bash
kubectl logs librechat-librechat-57b4f56689-zfw2t | grep -i userId
```

Example:

```
userId: "6980c40cc77704fe088e4675"
```

Save this value — it will be reused in the curl test.

---

## Step 7: Saturate the Rate Limit via Terminal Requests

The goal is to consume the rate limit outside LibreChat so that the UI starts receiving rate-limit errors.

Run the following script from your terminal:

```bash
#!/bin/bash

while true; do
  curl -X POST -v -L \
    -H "Content-Type: application/json" \
    -H "X-User-ID: 6980c40cc77704fe088e4675" \
    -H "Authorization: APIKEY REPLACE_YOUR_API_KEY" \
    -d '{
      "model": "gpt-4-1",
      "messages": [
        {
          "role": "user",
          "content": "QWERTYUIOP!"
        }
      ]
    }' \
    http://converse-llm.camer.digital/v1/chat/completions | jq
  sleep 1
done
```

> **⚠️ Ensure the X-User-ID matches the ID extracted from LibreChat logs.**

### Expected Result

**curl requests** will consistently return rate-limit errors (`429` / `409`) once the limit is exceeded.

**LibreChat UI** may:

- Show delayed or inconsistent errors
- Appear to bypass rate limits due to request timeouts

This confirms that rate limiting is enforced by Envoy, but LibreChat UI behavior can mask it under load.

---

## Conclusion

This test demonstrates that:

- `X-User-ID` rate limiting works correctly at the Envoy layer
- LibreChat UI timeouts can prevent immediate visibility of rate-limit errors
- Direct terminal requests are the most reliable way to validate enforcement behavior
