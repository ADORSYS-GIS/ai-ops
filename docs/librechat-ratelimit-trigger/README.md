# Low-Level Rate Limiting Test for Envoy AI Gateway with X-User-ID

This document explains how rate limiting works at the low level between **LibreChat** and the **Envoy AI Gateway**, focusing on the `X-User-ID` header mechanism.

The test is performed using direct `curl` requests to the Envoy gateway endpoint, without deploying LibreChat.

---

## Understanding the Rate Limiting Mechanism

### How LibreChat Sends User Identification

LibreChat is configured to forward user identification headers to custom endpoints. When configured with custom headers, LibreChat injects the `X-User-ID` header (along with `X-User-Email`) into all requests sent to the custom provider.

**Reference documentation:**
- [LibreChat Custom Endpoint Headers Configuration](https://www.librechat.ai/docs/configuration/librechat_yaml/object_structure/custom_endpoint#headers)

Example LibreChat configuration that enables this behavior:

```yaml
endpoints:
  custom:
    - name: "GPT-CUSTOM-PROVIDER"
      apiKey: "REPLACE_YOUR_API_KEY"
      baseURL: "http://converse-llm.camer.digital/v1"
      models:
        default: ["gpt-4-1"]
      headers:
        X-User-ID: "{{LIBRECHAT_USER_ID}}"
        X-User-Email: "{{LIBRECHAT_USER_EMAIL}}"
```

### How Envoy AI Gateway Uses X-User-ID for Rate Limiting

The Envoy AI Gateway uses the `X-User-ID` header to apply usage-based rate limits per user. When a request passes through Envoy, it extracts the `X-User-ID` value and uses it as a rate limit key. Each unique user ID receives their own rate limit quota.

**Reference documentation:**
- [Envoy AI Gateway Usage-Based Rate Limiting](https://aigateway.envoyproxy.io/docs/0.1/capabilities/usage-based-ratelimiting/#making-requests)

The rate limiting flow is:

```
LibreChat Request → Envoy Gateway (extracts X-User-ID) → Rate Limit Check → Upstream LLM
```

---

## Rate Limiting Test

This test validates that rate limiting based on `X-User-ID` is correctly enforced by Envoy using direct requests.

### Prerequisites

- Access to the Envoy gateway endpoint
- A valid API key for authentication
- A user ID to use for rate limiting (can be any string identifier)

### Endpoint Configuration

- **Endpoint URL:** `http://converse-llm.camer.digital/v1/chat/completions`
- **Rate Limit Key:** `X-User-ID` header

### Rate Limit Test Script

Run the following script to saturate the rate limit for a specific user ID:

```bash
#!/bin/bash

# Configuration
API_KEY="REPLACE_YOUR_API_KEY"
USER_ID="test-user-001"
MODEL="gpt-4-1"

echo "Starting rate limit test for user: $USER_ID"
echo "Press Ctrl+C to stop"
echo ""

counter=0
while true; do
  counter=$((counter + 1))
  
  # Capture response with HTTP status code
  response=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    -H "Content-Type: application/json" \
    -H "X-User-ID: ${USER_ID}" \
    -H "Authorization: APIKEY ${API_KEY}" \
    -d "{\"model\":\"${MODEL}\",\"messages\":[{\"role\":\"user\",\"content\":\"Test message ${counter}\"}]}" \
    http://converse-llm.camer.digital/v1/chat/completions)
  
  # Extract HTTP status code
  http_code=$(echo "$response" | grep "HTTP_CODE:" | cut -d':' -f2)
  body=$(echo "$response" | sed '/HTTP_CODE:/d')
  
  # Display result with HTTP status code
  echo "Request #$counter - HTTP $http_code"
  
  if [ "$http_code" = "429" ] || [ "$http_code" = "409" ]; then
    echo ">>> Rate limit exceeded!"
    echo "$body" | jq -r '.error.message // "No error message"' 2>/dev/null || echo "$body"
    echo ">>> Waiting 5 seconds before retry..."
    sleep 5
  else
    echo "Response: $body" | jq -r '.choices[0].message.content // "No content"' 2>/dev/null | head -c 100
    echo ""
    sleep 1
  fi
done
```

### Alternative: Multiple Users Test

To test that rate limits are applied per-user (not globally), run the script below in parallel terminals with different `USER_ID` values:

```bash
#!/bin/bash

# Run this script in different terminals with different USER_ID values
# Each user should have their own independent rate limit quota

API_KEY="REPLACE_YOUR_API_KEY"
USER_ID="${1:-test-user-001}"
MODEL="gpt-4-1"

echo "Testing rate limits for user: $USER_ID"
echo "Each user should have independent rate limits"
echo ""

counter=0
while true; do
  counter=$((counter + 1))
  response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
    -H "Content-Type: application/json" \
    -H "X-User-ID: ${USER_ID}" \
    -H "Authorization: APIKEY ${API_KEY}" \
    -d "{
      \"model\": \"${MODEL}\",
      \"messages\": [
        {
          \"role\": \"user\",
          \"content\": \"Count: ${counter}\"
        }
      ]
    }" \
    http://converse-llm.camer.digital/v1/chat/completions)
  
  http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d':' -f2)
  body=$(echo "$response" | sed '/HTTP_STATUS:/d')
  
  echo "[$USER_ID] Request #$counter - HTTP $http_status"
  
  if [ "$http_status" = "429" ] || [ "$http_status" = "409" ]; then
    echo ">>> Rate limit hit! Response: $body"
    echo ">>> Waiting 10 seconds before retry..."
    sleep 10
  else
    sleep 1
  fi
done
```

---

## Expected Results

### When Rate Limit is Enforced

- **HTTP 429 (Too Many Requests)** or **HTTP 409 (Conflict)**
- Response body contains rate limit error message
- `Retry-After` header may be present

### When Rate Limit is NOT Enforced

- **HTTP 200 (OK)**
- Valid JSON response with chat completions
- No rate limit headers in response

---

## How Rate Limiting is Applied

### Envoy Rate Limit Configuration

Envoy AI Gateway uses the `X-User-ID` header as a descriptor key for rate limiting. The configuration typically specifies:

1. **Rate limit unit** (e.g., minute, hour)
2. **Requests per unit** (e.g., 10 requests per minute)
3. **Descriptor key** (`X-User-ID`)
4. **Descriptor value** (the actual user ID from the request header)

### Request Flow

```
1. Client sends request with X-User-ID header
      ↓
2. Envoy Gateway extracts X-User-ID value
      ↓
3. Envoy checks rate limit counter for that user
      ↓
4. If under limit → Forward to upstream LLM
   If over limit  → Return HTTP 429
```

---

## Conclusion

This test demonstrates that:

- The `X-User-ID` header is the key mechanism for user-based rate limiting
- Envoy correctly identifies and tracks requests per user ID
- Rate limits are enforced independently for each unique user ID
- Direct terminal requests are the most reliable way to validate rate limit enforcement behavior

For LibreChat integration, ensure the custom endpoint configuration includes the `headers` section with `X-User-ID` template variable to forward user identification to the upstream gateway.
