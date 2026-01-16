# Envoy AI Gateway - Authorino Authorization Integration

Complete guide for integrating Authorino with Envoy AI Gateway to add authentication and authorization to your AI workloads.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Part 1: Install Authorino](#part-1-install-authorino)
- [Part 2: Configure Envoy Gateway Integration](#part-2-configure-envoy-gateway-integration)
- [Part 3: API Key Authentication](#part-3-api-key-authentication)
- [Part 4: OIDC/OAuth2 Authentication](#part-4-oidcoauth2-authentication)
- [Part 5: Model-Based Access Control](#part-5-model-based-access-control)
- [Part 6: Rate Limiting](#part-6-rate-limiting)
- [Part 7: Monitoring and Observability](#part-7-monitoring-and-observability)
- [Part 8: Troubleshooting](#part-8-troubleshooting)
- [Part 9: Production Best Practices](#part-9-production-best-practices)

## Overview

Authorino is a Kubernetes-native authorization service that provides:
- **Multiple Authentication Methods**: API Keys, JWT/OIDC, mTLS, OAuth2
- **Policy-Based Authorization**: Using Open Policy Agent (OPA)
- **Response Manipulation**: Add headers, transform requests
- **Fine-Grained Access Control**: User, role, and resource-based policies
- **Integration with Envoy**: Via External Authorization (ExtAuth) filter


## Prerequisites

### Required
- Envoy AI Gateway installed and configured (see main README)
- kubectl CLI with cluster access
- Kubernetes cluster (k3d, k3s, or production cluster)

### Recommended
- cert-manager knowledge (for TLS certificates)
- Basic understanding of Kubernetes RBAC
- Familiarity with OAuth2/OIDC concepts

## Part 1: Install Authorino

### 1.1 Install cert-manager

Authorino requires cert-manager for certificate management:

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.2/cert-manager.yaml

# Wait for cert-manager to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/instance=cert-manager \
  -n cert-manager \
  --timeout=300s

# Verify installation
kubectl get pods -n cert-manager
```

**Expected output:**
```
NAME                                      READY   STATUS    RESTARTS   AGE
cert-manager-7d9f6c6d4f-xxxxx            1/1     Running   0          2m
cert-manager-cainjector-5d7f8c8d4-xxxxx  1/1     Running   0          2m
cert-manager-webhook-5f7f8c8d4f-xxxxx    1/1     Running   0          2m
```

### 1.2 Install Authorino Operator

```bash
# Install Authorino Operator
kubectl apply -f https://raw.githubusercontent.com/Kuadrant/authorino-operator/main/config/deploy/manifests.yaml

# Wait for operator to be ready
kubectl wait --for=condition=ready pod \
  -l control-plane=controller-manager \
  -n authorino-operator \
  --timeout=300s

# Verify operator installation
kubectl get pods -n authorino-operator
```

**Expected output:**
```
NAME                                                  READY   STATUS    RESTARTS   AGE
authorino-operator-controller-manager-xxxxx-xxxxx    2/2     Running   0          2m
```

### 1.3 Deploy Authorino Instance

```bash
kubectl apply -f authorino.yaml

# Wait for Authorino to be ready
kubectl wait --for=condition=ready pod \
  -l authorino-resource=authorino \
  -n default \
  --timeout=300s

# Verify Authorino deployment
kubectl get pods -n default -l authorino-resource=authorino
kubectl get svc -n default | grep authorino
```

**Expected services:**
```
authorino-authorino-authorization   ClusterIP   10.x.x.x   <none>        50051/TCP,5001/TCP   2m
authorino-oidc                      ClusterIP   10.x.x.x   <none>        8083/TCP             2m
authorino-metrics                   ClusterIP   10.x.x.x   <none>        8080/TCP             2m
```

### 1.4 Verify Authorino Installation

```bash
# Check Authorino logs
AUTHORINO_POD=$(kubectl get pods -n default -l authorino-resource=authorino -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n default $AUTHORINO_POD --tail=20

# Check Authorino version
kubectl get deployment -n default authorino-controller-manager -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Part 2: Configure Envoy Gateway Integration

### 2.1 Create SecurityPolicy

The SecurityPolicy configures Envoy Gateway to use Authorino for external authorization:

```bash
kubectl apply -f security-policy.yaml
```

**Configuration explanation:**
- `targetRefs`: Links the policy to the AI Gateway
- `extAuth.grpc`: Configures gRPC external authorization
- `backendRef`: Points to Authorino service
- `failOpen: false`: Denies requests if Authorino is unavailable (secure default)

### 2.2 Verify SecurityPolicy

```bash
# Check SecurityPolicy status
kubectl get securitypolicy ai-gateway-auth -n default

# Describe for detailed information
kubectl describe securitypolicy ai-gateway-auth -n default

# Verify it's attached to the gateway
kubectl get gateway envoy-ai-gateway-basic -n default -o yaml | grep -A 10 "policyRefs"
```

### 2.3 Test Without Authentication

```bash
# This should now fail with 401/403
curl -v -H "Content-Type: application/json" \
  -d '{
    "model": "smart-llm",
    "messages": [{"role": "user", "content": "Hello"}]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

**Expected response:**
```
HTTP/1.1 401 Unauthorized
...
RBAC: access denied
```

This confirms the SecurityPolicy is active and blocking unauthenticated requests.

## Part 3: API Key Authentication

### 3.1 Create AuthConfig for API Keys

```bash
kubectl apply -f authconfig.yaml
```

**AuthConfig structure:**
- `hosts`: Defines which requests this AuthConfig applies to
- `authentication`: Validates API keys from Kubernetes secrets
- `authorization`: Uses OPA to define access policies
- `response`: Adds user context to forwarded requests

### 3.2 Create API Key Secrets

```bash
kubectl apply -f api-key-secret.yaml
```

**Secret requirements:**
- Must have label `app: ai-gateway` (matches AuthConfig selector)
- Must have label `authorino.kuadrant.io/managed-by: authorino`
- API key stored in `api_key` field
- Annotations can store user metadata

### 3.3 Verify API Key Configuration

```bash
# List all API key secrets
kubectl get secrets -n default -l app=ai-gateway

# Check AuthConfig status
kubectl get authconfig ai-gateway-apikey-auth -n default -o yaml

# Test configuration with Authorino logs
kubectl logs -n default -l authorino-resource=authorino -f
```

### 3.4 Test API Key Authentication

**Test without API key (should fail):**
```bash
curl -v -H "Content-Type: application/json" \
  -d '{
    "model": "gemini",
    "messages": [{"role": "user", "content": "Hello"}]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

Expected: `401 Unauthorized` with message "credential not found"

**Test with valid API key (should succeed):**
```bash
# Test with user1's API key
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer user1-secret-key-12345" \
  -d '{
    "model": "smart-llm",
    "messages": [{"role": "user", "content": "Hello from user1"}]
  }' \
  $GATEWAY_URL/v1/chat/completions

# Test with user2's API key
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer user2-secret-key-67890" \
  -d '{
    "model": "smart-llm",
    "messages": [{"role": "user", "content": "Hello from user2"}]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

Expected: Successful response from GCP Vertex AI

**Test with invalid API key (should fail):**
```bash
curl -v -H "Content-Type: application/json" \
  -H "Authorization: Bearer invalid-key-xxxxx" \
  -d '{
    "model": "smart-llm",
    "messages": [{"role": "user", "content": "Hello"}]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

Expected: `401 Unauthorized` with message "the API Key provided is invalid"

## Part 4: OIDC/OAuth2 Authentication

### 4.1 Configure OIDC Authentication

For enterprise deployments using OAuth2/OIDC providers (Keycloak, Auth0, Google, Okta):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: authorino.kuadrant.io/v1beta2
kind: AuthConfig
metadata:
  name: ai-gateway-oidc-auth
  namespace: default
  labels:
    authorino: enabled
spec:
  hosts:
    - "*"
  
  # OIDC JWT token validation
  authentication:
    "jwt-auth":
      jwt:
        issuerUrl: https://YOUR_OIDC_PROVIDER/.well-known/openid-configuration
      credentials:
        authorizationHeader:
          prefix: Bearer
  
  # Authorization based on JWT claims
  authorization:
    "role-based-access":
      opa:
        rego: |
          import future.keywords.if
          
          # Allow admins full access
          allow if {
            input.auth.identity.realm_access.roles[_] == "admin"
          }
          
          # Allow users with ai-user role
          allow if {
            input.auth.identity.realm_access.roles[_] == "ai-user"
          }
          
          # Deny by default
          default allow = false
  
  # Add user context to headers
  response:
    success:
      headers:
        "x-auth-user":
          plain:
            value: '{auth.identity.sub}'
        "x-auth-email":
          plain:
            value: '{auth.identity.email}'
        "x-auth-roles":
          plain:a
            value: '{auth.identity.realm_access.roles}'
  
  denyWith:
    unauthenticated:
      code: 401
      message:
        value: "Authentication required. Please provide a valid JWT token."
    unauthorized:
      code: 403
      message:
        value: "Access denied. You need 'admin' or 'ai-user' role."
EOF
```

**Configuration for popular OIDC providers:**

**Google:**
```yaml
issuerUrl: https://accounts.google.com/.well-known/openid-configuration
```

**Auth0:**
```yaml
issuerUrl: https://YOUR_DOMAIN.auth0.com/.well-known/openid-configuration
```

**Keycloak:**
```yaml
issuerUrl: https://YOUR_KEYCLOAK_URL/realms/YOUR_REALM/.well-known/openid-configuration
```

**Okta:**
```yaml
issuerUrl: https://YOUR_DOMAIN.okta.com/.well-known/openid-configuration
```

### 4.2 Test OIDC Authentication

```bash
# First, obtain a JWT token from your OIDC provider
# Example with Keycloak:
TOKEN=$(curl -X POST "https://YOUR_KEYCLOAK_URL/realms/YOUR_REALM/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=YOUR_USERNAME" \
  -d "password=YOUR_PASSWORD" \
  -d "grant_type=password" \
  -d "client_id=YOUR_CLIENT_ID" \
  -d "client_secret=YOUR_CLIENT_SECRET" \
  | jq -r '.access_token')

# Use the token to access the gateway
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "model": "vertex-virtual-model",
    "messages": [{"role": "user", "content": "Hello with OIDC"}]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

## Part 5: Model-Based Access Control

### 5.1 Create AuthConfig with Fine-Grained Model Access

```bash
cat <<EOF | kubectl apply -f -
apiVersion: authorino.kuadrant.io/v1beta2
kind: AuthConfig
metadata:
  name: ai-gateway-model-access
  namespace: default
  labels:
    authorino: enabled
spec:
  hosts:
    - "*"
  
  # API Key authentication
  authentication:
    "api-key":
      apiKey:
        selector:
          matchLabels:
            app: ai-gateway
        allNamespaces: true
      credentials:
        authorizationHeader:
          prefix: Bearer
  
  # Model-based authorization
  authorization:
    "model-access-control":
      opa:
        rego: |
          import future.keywords.if
          
          # Parse the request body to extract requested model
          body := object.get(input.context.request.http, "body", "")
          decoded_body := json.unmarshal(body)
          requested_model := object.get(decoded_body, "model", "")
          
          # Get user's allowed models from secret annotation
          allowed_models_str := object.get(input.auth.identity.metadata.annotations, "allowed_models", "")
          allowed_models := split(allowed_models_str, ",")
          
          # Check if user has wildcard access
          has_wildcard if {
            allowed_models[_] == "*"
          }
          
          # Check if user has access to specific model
          has_model_access if {
            trim_space(allowed_models[_]) == requested_model
          }
          
          # Allow if user has wildcard or specific model access
          allow if has_wildcard
          allow if has_model_access
          
          # Deny by default
          default allow = false
  
  # Add authorization metadata to response
  response:
    success:
      headers:
        "x-auth-user":
          plain:
            value: '{auth.identity.metadata.annotations.user}'
        "x-allowed-models":
          plain:
            value: '{auth.identity.metadata.annotations.allowed_models}'
  
  denyWith:
    unauthenticated:
      code: 401
      message:
        value: "Authentication required"
    unauthorized:
      code: 403
      message:
        value: "Access denied. You don't have permission to use this model."
EOF
```

### 5.2 Create API Keys with Model Permissions

```bash
# Admin with access to all models
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: api-key-admin-full
  namespace: default
  labels:
    authorino.kuadrant.io/managed-by: authorino
    app: ai-gateway
  annotations:
    user: admin
    email: admin@example.com
    allowed_models: "*"
stringData:
  api_key: admin-full-access-key-12345
type: Opaque
EOF

# User with access to vertex-virtual-model only
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: api-key-limited-user
  namespace: default
  labels:
    authorino.kuadrant.io/managed-by: authorino
    app: ai-gateway
  annotations:
    user: limited-user
    email: limited@example.com
    allowed_models: "vertex-virtual-model"
stringData:
  api_key: limited-user-key-67890
type: Opaque
EOF

# User with access to multiple specific models
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: api-key-multi-model-user
  namespace: default
  labels:
    authorino.kuadrant.io/managed-by: authorinodiagram
    app: ai-gateway
  annotations:
    user: multi-model-user
    email: multi@example.com
    allowed_models: "vertex-virtual-model,gpt-4,claude-3"
stringData:
  api_key: multi-model-key-11111
type: Opaque
EOF

# User with no model access
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: api-key-no-access
  namespace: default
  labels:
    authorino.kuadrant.io/managed-by: authorino
    app: ai-gateway
  annotations:
    user: no-access-user
    email: noaccess@example.com
    allowed_models: ""
stringData:
  api_key: no-access-key-99999
type: Opaque
EOF
```

### 5.3 Test Model-Based Access Control

**Test admin with wildcard access (should succeed):**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer admin-full-access-key-12345" \
  -d '{
    "model": "vertex-virtual-model",
    "messages": [{"role": "user", "content": "Admin test"}]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

**Test limited user with allowed model (should succeed):**
```bash
curl -H "Content-Type: application/json" \
  -H "Authorization: Bearer limited-user-key-67890" \
  -d '{
    "model": "vertex-virtual-model",
    "messages": [{"role": "user", "content": "Limited user test"}]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

**Test limited user with disallowed model (should fail):**
```bash
curl -v -H "Content-Type: application/json" \
  -H "Authorization: Bearer limited-user-key-67890" \
  -d '{
    "model": "some-other-model",
    "messages": [{"role": "user", "content": "This should fail"}]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

Expected: `403 Forbidden` with message "Access denied. You don't have permission to use this model."

**Test user with no access (should fail):**
```bash
curl -v -H "Content-Type: application/json" \
  -H "Authorization: Bearer no-access-key-99999" \
  -d '{
    "model": "vertex-virtual-model",
    "messages": [{"role": "user", "content": "This should fail"}]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

Expected: `403 Forbidden`

## Part 6: Rate Limiting

### 6.1 Create AuthConfig with Rate Limit Metadata

```bash
cat <<EOF | kubectl apply -f -
apiVersion: authorino.kuadrant.io/v1beta2
kind: AuthConfig
metadata:
  name: ai-gateway-with-ratelimit
  namespace: default
  labels:
    authorino: enabled
spec:
  hosts:
    - "*"
  
  authentication:
    "api-key":
      apiKey:
        selector:
          matchLabels:
            app: ai-gateway
        allNamespaces: true
      credentials:
        authorizationHeader:
          prefix: Bearer
  
  authorization:
    "allow-all":
      opa:
        rego: |
          allow = true
  
  # Add rate limit information to headers
  response:
    success:
      headers:
        "x-user-id":
          plain:
            value: '{auth.identity.metadata.annotations.user}'
        "x-user-tier":
          plain:
            value: '{auth.identity.metadata.annotations.tier}'
        "x-ratelimit-limit":
          plain:
            value: '{auth.identity.metadata.annotations.rate_limit}'
EOF
```

### 6.2 Create API Keys with Rate Limit Metadata

```bash
# Free tier user - 10 requests/minute
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: api-key-free-tier
  namespace: default
  labels:
    authorino.kuadrant.io/managed-by: authorino
    app: ai-gateway
  annotations:
    user: free-user
    tier: free
    rate_limit: "10"
stringData:
  api_key: free-tier-key-12345
type: Opaque
EOF

# Pro tier user - 100 requests/minute
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: api-key-pro-tier
  namespace: default
  labels:
    authorino.kuadrant.io/managed-by: authorino
    app: ai-gateway
  annotations:
    user: pro-user
    tier: pro
    rate_limit: "100"
stringData:
  api_key: pro-tier-key-67890
type: Opaque
EOF

# Enterprise tier user - unlimited
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: api-key-enterprise-tier
  namespace: default
  labels:
    authorino.kuadrant.io/managed-by: authorino
    app: ai-gateway
  annotations:
    user: enterprise-user
    tier: enterprise
    rate_limit: "unlimited"
stringData:
  api_key: enterprise-tier-key-99999
type: Opaque
EOF
```

### 6.3 Implement Rate Limiting with Envoy

Create a RateLimitPolicy (requires Envoy Gateway rate limiting):

```bash
cat <<EOF | kubectl apply -f -
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: ai-gateway-rate-limit
  namespace: default
spec:
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: envoy-ai-gateway-basic
  rateLimit:
    type: Global
    global:
      rules:
        - clientSelectors:
            - headers:
                - name: x-user-tier
                  value: free
          limit:
            requests: 10
            unit: Minute
        - clientSelectors:
            - headers:
                - name: x-user-tier
                  value: pro
          limit:
            requests: 100
            unit: Minute
EOF
```

**Note:** This requires setting up a rate limit service. For production, consider using Redis-based rate limiting.

## Part 7: Monitoring and Observability

### 7.1 Access Authorino Metrics

```bash
# Port forward to Authorino metrics endpoint
kubectl port-forward -n default svc/authorino-metrics 8080:8080 &

# Query metrics
curl http://localhost:8080/metrics

# Filter for auth metrics
curl http://localhost:8080/metrics | grep authorino
```

### 7.2 Key Metrics to Monitor

**Authentication Metrics:**
```
# Total authentication requests
authorino_auth_server_evaluator_total

# Authentication duration
authorino_auth_server_evaluator_duration_seconds

# Authentication errors
authorino_auth_server_evaluator_errors_total
```

**Authorization Metrics:**
```
# Authorization requests
authorino_auth_server_authorization_total

# Authorization denials
authorino_auth_server_authorization_denied_total
```

### 7.3 View Authorino Logs

```bash
# Get Authorino pod name
AUTHORINO_POD=$(kubectl get pods -n default -l authorino-resource=authorino -o jsonpath='{.items[0].metadata.name}')

# Follow logs
kubectl logs -n default $AUTHORINO_POD -f

# Filter for authentication events
kubectl logs -n default $AUTHORINO_POD | grep "auth"

# Filter for denied requests
kubectl logs -n default $AUTHORINO_POD | grep "denied"

# Filter for specific user
kubectl logs -n default $AUTHORINO_POD | grep "user1"
```

### 7.4 Monitor Gateway Logs for Auth Events

```bash
# Get gateway pod name
POD_NAME=$(kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic -o jsonpath='{.items[0].metadata.name}')

# Watch for 401/403 responses
kubectl logs -n envoy-gateway-system $POD_NAME -f | grep -E "401|403"

# View full authorization flow
kubectl logs -n envoy-gateway-system $POD_NAME -f | grep "ext_authz"
```



## Part 8: Troubleshooting

### 8.1 Common Issues

#### Issue 1: All Requests Return 403

**Symptoms:**
```
HTTP/1.1 403 Forbidden
RBAC: access denied
```

**Diagnosis:**
```bash
# Check if AuthConfig exists and has correct label
kubectl get authconfig -n default
kubectl get authconfig ai-gateway-apikey-auth -n default -o yaml | grep -A 5 labels

# Should show:
# labels:
#   authorino: enabled
```

**Solution:**
```bash
# Verify AuthConfig label matches Authorino selector
kubectl get authorino authorino -n default -o yaml | grep authConfigLabel