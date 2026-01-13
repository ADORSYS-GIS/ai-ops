# Envoy AI Gateway with GCP Vertex AI Integration

Complete guide for integrating Google Cloud Vertex AI as a provider in the Envoy AI Gateway with intelligent fallback routing to self-hosted models.

## Overview

This integration enables:
- **Primary Provider**: Self-hosted models via KServe (Qwen 2.5:0.5b)
- **Fallback Provider**: GCP Vertex AI (Gemini 2.5 Flash)
- **Automatic Failover**: Seamless switching between providers on errors
- **Streaming Support**: Server-sent events for real-time responses
- **OpenAI-Compatible API**: Standard interface for all providers


## Prerequisites

### Required Tools
- Docker
- kubectl CLI
- k3d or Multipass (for local Kubernetes)
- gcloud CLI ([Installation Guide](https://cloud.google.com/sdk/docs/install-sdk))

### GCP Requirements
- Active GCP account with billing enabled
- GCP project with Vertex AI API enabled
- Service account with appropriate permissions

##  Environment Setup

For  Environment setup use the [Model Virtualization & Provider Fallback Guide ](../model-virtualization-provider-fallback.md). Follow the Environment Setup entirely.

##  GCP Service Account Configuration

### 2.1 Install and Configure gcloud CLI

Follow the [official installation guide](https://cloud.google.com/sdk/docs/install-sdk) for your operating system.

```bash
# Initialize gcloud
gcloud init

# Set your project
gcloud config set project YOUR_PROJECT_ID
```

### 2.2 Enable Required APIs

```bash
# Enable Vertex AI API
gcloud services enable aiplatform.googleapis.com

# Enable Service Usage API
gcloud services enable serviceusage.googleapis.com

# Verify APIs are enabled
gcloud services list --enabled | grep -E "aiplatform|serviceusage"
```

### 2.3 Create Service Account

Follow the [IAM Keys documentation](https://cloud.google.com/iam/docs/keys-create-delete#gcloud) to create and manage service account keys.

```bash
# Create service account
gcloud iam service-accounts create envoy-ai-gateway \
  --display-name="Envoy AI Gateway Service Account" \
  --description="Service account for Envoy AI Gateway to access Vertex AI"

# Grant necessary permissions
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:envoy-ai-gateway@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:envoy-ai-gateway@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageConsumer"

# Create and download service account key
gcloud iam service-accounts keys create ./service-account-key.json \
  --iam-account=envoy-ai-gateway@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Verify the key file
cat ./service-account-key.json | jq .
```

### 2.4 Test Service Account Authentication

```bash
# Activate the service account
gcloud auth activate-service-account --key-file=./service-account-key.json

# Get an access token
ACCESS_TOKEN=$(gcloud auth print-access-token)

# Test direct API call to Vertex AI
curl -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  "https://us-central1-aiplatform.googleapis.com/v1/projects/YOUR_PROJECT_ID/locations/us-central1/publishers/google/models/gemini-2.0-flash-exp:generateContent" \
  -d '{
    "contents": [{
      "role": "user",
      "parts": [{"text": "Say hello"}]
    }]
  }'
```

If you receive a valid JSON response with content, your service account is configured correctly.

##  Deploy Self-Hosted Model with KServe To Use For Fallback Logic 

**Apply Inference Service**
```bash
kubectl apply -f model.yaml
```
**Wait for Pod to be Successfully Created**
```bash
kubectl wait --for=condition=Ready inferenceservice/qwen-secondary --timeout=600s
```

**Quick verification:**
```bash
# Check if KServe model is deployed
kubectl get inferenceservice -n default

```
**Expected Output**
```bash
qwen-secondary   http://qwen-secondary.default.svc.cluster.local   True           100                              qwen-secondary-predictor-00001   4h9m

```


## Part 4: Configure GCP Vertex AI Backend

### 4.1 Create Kubernetes Secret

```bash
# Create secret from your service account key file
kubectl create secret generic envoy-ai-gateway-basic-gcp-service-account-key-file \
  --from-file=service_account.json=./<service-account-key-file> \
  -n default

# Verify secret creation
kubectl get secret envoy-ai-gateway-basic-gcp-service-account-key-file -n default

# Validate secret content
kubectl get secret envoy-ai-gateway-basic-gcp-service-account-key-file -n default \
  -o jsonpath='{.data.service_account\.json}' | base64 -d | jq .
```

### 4.2 Apply Gateway Configuration

Create and apply the base gateway configuration:

```bash
# Apply basic gateway setup 
kubectl apply -f basic.yaml


# Verify gateway pods are running
kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic
```

### 4.3 Deploy KServe Backend Configuration

```bash
# Apply KServe model backend (kserve-model.yaml)
kubectl apply -f kserve-backend.yaml

# Verify AIServiceBackend
kubectl get aiservicebackend envoy-ai-gateway-qwen-secondary -n default
```

### 4.4 Deploy GCP Vertex AI Configuration

Update `gcp_vertex.yaml` with your GCP project details:

```yaml
# In gcp_vertex.yaml, update these values:
spec:
  gcpCredentials:
    projectName: YOUR_PROJECT_ID  # Replace with your GCP project ID
    region: us-central1           # Replace with your preferred region
```

Apply the configuration:

```bash
# Apply GCP Vertex AI backend configuration
kubectl apply -f gcp_vertex.yaml

# Verify all resources are created
kubectl get aiservicebackend,backendsecuritypolicy,backend,aigatewayroute -n default
```

### 4.5 Verify Configuration Status

```bash
# Check AIServiceBackend status
kubectl get aiservicebackend -n default -o wide

# Check BackendSecurityPolicy
kubectl describe backendsecuritypolicy envoy-ai-gateway-basic-gcp-credentials -n default

# Check AIGatewayRoute
kubectl describe aigatewayroute envoy-ai-gateway-fallback -n default

# View gateway logs
POD_NAME=$(kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n envoy-gateway-system $POD_NAME --tail=50
```

## Part 5: Testing the Integration

### 5.1 Test Primary Provider (KServe Model)

**Configure Port Forwarding**
```bash
# In another terminal
export ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')

kubectl port-forward -n envoy-gateway-system svc/$ENVOY_SERVICE 8080:80

```


```bash
# Test the KServe model directly
export GATEWAY_URL="http://localhost:8080"

curl -H "Content-Type: application/json" \
  -d '{
    "model": "vertex-virtual-model",
    "messages": [
      {"role": "user", "content": "What is artificial intelligence?"}
    ]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

Expected behavior: The request should be routed to the KServe model (Priority 0: qwen2.5:0.5b).

### 5.2 Test Fallback Mechanism And The GCP Integration

To test the fallback to GCP Vertex AI, simulate a failure in the primary provider:

```bash
# delete inference service 
kubectl delete isvc qwen-secondary
sleep 30

# Apply Backend-Tls-Policy
kubectl apply -f Backend-tls-policy.yaml

# Test again - should fallback to GCP Vertex AI
curl -H "Content-Type: application/json" \
  -d '{
    "model": "vertex-virtual-model",
    "messages": [
      {"role": "user", "content": "What is cloud computing?"}
    ]
  }' \
  $GATEWAY_URL/v1/chat/completions

```
```bash
for i in 1 2 3 4 5; do                    
  curl -H "Content-Type: application/json" \
    -d '{
      "model": "vertex-virtual-model",
      "messages": [
        {"role": "user", "content": "Explain AI in one sentence."}
      ]
    }' \
    $GATEWAY_URL/v1/chat/completions
done

```
**Check Logs**
```bash
# View gateway logs
POD_NAME=$(kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n envoy-gateway-system $POD_NAME --tail=50
```


### 5.3 Test Streaming Responses

```bash
# Test with streaming enabled
curl -N -H "Content-Type: application/json" \
  -d '{
    "model": "vertex-virtual-model",
    "messages": [
      {"role": "user", "content": "Explain quantum computing in simple terms."}
    ],
    "stream": true
  }' \
  $GATEWAY_URL/v1/chat/completions
```




## Troubleshooting

### Error: Authentication Failed

**Symptoms:**
- 401 Unauthorized errors
- "Invalid credentials" messages

**Solution:**
```bash
# Verify service account has correct permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:envoy-ai-gateway@YOUR_PROJECT_ID.iam.gserviceaccount.com"

# Check secret is correctly formatted
kubectl get secret envoy-ai-gateway-basic-gcp-service-account-key-file -n default \
  -o jsonpath='{.data.service_account\.json}' | base64 -d | jq 'has("project_id", "private_key", "client_email")'

# Recreate secret if needed
kubectl delete secret envoy-ai-gateway-basic-gcp-service-account-key-file -n default
kubectl create secret generic envoy-ai-gateway-basic-gcp-service-account-key-file \
  --from-file=service_account.json=./service-account-key.json \
  -n default
```

### Error: Model Not Found

**Symptoms:**
- 404 Not Found errors
- Model name errors

**Solution:**
```bash
# List available models in your region
gcloud ai models list --region=us-central1 --project=YOUR_PROJECT_ID

# Update modelNameOverride in gcp_vertex.yaml to match available models
# Common models: gemini-2.0-flash-exp, gemini-1.5-pro, gemini-1.5-flash
```


## Monitoring and Observability

### View Request Logs

```bash
# Real-time log streaming
POD_NAME=$(kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n envoy-gateway-system $POD_NAME -f

# Filter for errors
kubectl logs -n envoy-gateway-system $POD_NAME | grep -i error

# Filter for specific backend
kubectl logs -n envoy-gateway-system $POD_NAME | grep -i gcp
```



### Metrics Collection

**Install Promtheus**
```bash
kubectl apply -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/main/examples/monitoring/monitoring.yaml
```
**Let's wait for a while until the Prometheus is up and running.**
```bash
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring
```
**To access the Prometheus dashboard, you need to port-forward the Prometheus service to your local machine like this:**
```bash
kubectl port-forward -n monitoring svc/prometheus 9090:9090
```
**Note: if you are working in multipass then port forward this way and then use the vm's ip to access the dasboard on your host machine**
```bash
kubectl port-forward --address 0.0.0.0 -n monitoring svc/prometheus 9090:9090
```
**Make Requests To Vertex AI model Then Navigate the dashboard or make a curl request instead like:**
```bash
# Get total number of AI tokens processed by your Envoy AI Gateway
curl http://localhost:9090/api/v1/query --data-urlencode \
  'query=sum(gen_ai_client_token_usage_sum{gateway_envoyproxy_io_owning_gateway_name = "envoy-ai-gateway-basic"}) by (gen_ai_request_model, gen_ai_token_type)' \
  | jq '.data.result[]'
```




## Cleanup

To remove all deployed resources:

```bash
# Delete AI Gateway resources
kubectl delete aigatewayroute --all -n default
kubectl delete aiservicebackend --all -n default
kubectl delete backendsecuritypolicy --all -n default
kubectl delete backend --all -n default
kubectl delete backendtrafficpolicy --all -n default

# Delete gateway
kubectl delete gateway envoy-ai-gateway-basic -n default

# Delete secrets
kubectl delete secret envoy-ai-gateway-basic-gcp-service-account-key-file -n default

# Uninstall Envoy Gateway
helm uninstall eg -n envoy-gateway-system
kubectl delete namespace envoy-gateway-system

# Delete k3d cluster
k3d cluster delete ai-gateway
```





