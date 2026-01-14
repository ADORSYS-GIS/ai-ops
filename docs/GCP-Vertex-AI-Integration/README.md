# Envoy AI Gateway with GCP Vertex AI Integration

Complete guide for integrating Google Cloud Vertex AI as a provider in the Envoy AI Gateway with intelligent fallback routing between multiple GCP Vertex AI models.

## Overview

This integration enables:
- **Primary Provider**: GCP Vertex AI (Gemini 2.5 Pro - intentionally broken for demo)
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

## Part 1: Environment Setup


You can choose between two approaches for your Kubernetes cluster:

### Option A: Using Multipass VM

#### Create VM
```bash
multipass launch --name aiops --cpus 2 --mem 4G --disk 20G
multipass shell aiops
```
### Update and Upgrade system
```sh
sudo apt update 
sudo apt upgrade
```
#### Install K3s
```bash
curl -sfL https://get.k3s.io | sh -
mkdir ~/.kube
sudo cp -r /etc/rancher/k3s/k3s.yaml ~/.kube/config 
sudo chmod 644 ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG="$HOME/.kube/config"' >> "$HOME/.${0##*/}rc"

```

### Option B: Using k3d (Docker-based)

**Prerequisites**: Ensure Docker is installed and running on your system.

#### Install k3d
```bash
# Linux/macOS
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Or using wget
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# Verify installation
k3d version
```

#### Create k3d Cluster
```bash
# Create cluster with appropriate resources
k3d cluster create aiops \
  --image rancher/k3s:v1.32.0-k3s1 \
  --wait

# Set kubeconfig
export KUBECONFIG="$(k3d kubeconfig write aiops)"
echo "export KUBECONFIG=$(k3d kubeconfig write aiops)" >> "$HOME/.${0##*/}rc"

# Verify cluster
kubectl cluster-info
kubectl get nodes

```


#### k3d Cluster Management Commands
```bash
# Stop cluster
k3d cluster stop aiops

# Start cluster
k3d cluster start aiops

# Delete cluster
k3d cluster delete aiops

# List clusters
k3d cluster list
```

---

### Common Setup (Both Options)

### Install Helm
```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

### Install K9s (Optional)
```bash
curl -sS https://webinstall.dev/k9s | sh
```
**Install Phoenix for LLM observability**
```sh
# Install Phoenix using PostgreSQL storage.
helm install phoenix oci://registry-1.docker.io/arizephoenix/phoenix-helm \
  --namespace envoy-ai-gateway-system \
  --create-namespace \
  --set auth.enableAuth=false \
  --set server.port=6006
  ```
**Install AI Gateway CRDs**
```bash
helm upgrade -i aieg-crd oci://docker.io/envoyproxy/ai-gateway-crds-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --create-namespace
```
**Install AI Gateway Resources and Configure with Open Telemetry**
```bash
helm install aieg oci://docker.io/envoyproxy/ai-gateway-helm \
  --version v0.0.0-latest \
  --namespace envoy-ai-gateway-system \
  --set "extProc.extraEnvVars[0].name=OTEL_EXPORTER_OTLP_ENDPOINT" \
  --set "extProc.extraEnvVars[0].value=http://phoenix-svc.envoy-ai-gateway-system.svc.cluster.local:6006" \
  --set "extProc.extraEnvVars[1].name=OTEL_METRICS_EXPORTER" \
  --set "extProc.extraEnvVars[1].value=none"
# OTEL_SERVICE_NAME defaults to "ai-gateway" if not set
# OTEL_METRICS_EXPORTER=none because Phoenix only supports traces, not metrics

kubectl wait --timeout=2m -n envoy-ai-gateway-system deployment/ai-gateway-controller --for=condition=Available
```

**Install Envoy Gateway**
```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
    --version v1.6.0 \
    --namespace envoy-gateway-system \
    --create-namespace \
    -f https://raw.githubusercontent.com/envoyproxy/ai-gateway/v0.4.0/manifests/envoy-gateway-values.yaml

kubectl wait --timeout=2m -n envoy-gateway-system deployment/envoy-gateway --for=condition=Available
```
**Verify Installation**
```bash
kubectl get pods -n envoy-ai-gateway-system
```
You should see all pods running
```text
NAME                                     READY   STATUS    RESTARTS   AGE
ai-gateway-controller-6f4cd954d9-h7vdv   1/1     Running   0          2m
phoenix-8f546998b-ztwzq                  1/1     Running   0          2m28s
phoenix-postgresql-0                     1/1     Running   0          2m28s
```


## Part 2: GCP Service Account Configuration

### 2.1 Install and Configure gcloud CLI

Follow the [official installation guide](https://cloud.google.com/sdk/docs/install-sdk) for your operating system.

**Important:** Before proceeding, define your GCP Project ID   as an environment variable. This ensures consistency and avoids hardcoding values throughout the setup.
```bash
# Set your GCP Project ID (replace with your actual project ID)
export PROJECT_ID="your-gcp-project-id" # Replace it with yout own Project ID 

# Verify the variable is set
echo $PROJECT_ID
```

```bash
# Initialize gcloud
gcloud init

# Set your project
gcloud config set project $PROJECT_ID
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
  --member="serviceAccount:envoy-ai-gateway@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:envoy-ai-gateway@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/serviceusage.serviceUsageConsumer"

# Create and download service account key
gcloud iam service-accounts keys create ./service-account-key.json \
  --iam-account=envoy-ai-gateway@$PROJECT_ID.iam.gserviceaccount.com

# Verify the key file
cat ./service-account-key.json | jq .
```

### 2.4 Test Service Account Authentication
**Don't Forget to Replace the placeholder for the service account key file with the right name and path same while creating the secret in 3.1 of Part3.**

```bash
# Activate the service account
gcloud auth activate-service-account --key-file=./<service-account-file.json>

# Get an access token
ACCESS_TOKEN=$(gcloud auth print-access-token)

# Test direct API call to Vertex AI
curl -X POST \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  "https://us-central1-aiplatform.googleapis.com/v1/projects/$PROJECT_ID/locations/us-central1/publishers/google/models/gemini-2.0-flash-exp:generateContent" \
  -d '{
    "contents": [{
      "role": "user",
      "parts": [{"text": "Say hello"}]
    }]
  }'
```

If you receive a valid JSON response with content, your service account is configured correctly.

## Part 3: Configure GCP Vertex AI Backend

### 3.1 Create Kubernetes Secret

```bash
# Create secret from your service account key file
kubectl create secret generic envoy-ai-gateway-basic-gcp-service-account-key-file \
  --from-file=service_account.json=./<service-account-file.json> \
  -n default

# Verify secret creation
kubectl get secret envoy-ai-gateway-basic-gcp-service-account-key-file -n default

# Validate secret content
kubectl get secret envoy-ai-gateway-basic-gcp-service-account-key-file -n default \
  -o jsonpath='{.data.service_account\.json}' | base64 -d | jq .
```

### 3.2 Apply Gateway Configuration

Create and apply the base gateway configuration:

```bash
# Apply basic gateway setup 
kubectl apply -f basic.yaml

# Verify gateway pods are running
kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic
```

### 3.3 Deploy GCP Vertex AI Configuration

Update `gcp_vertex.yaml` with your GCP project details:

```yaml
# In gcp_vertex.yaml, update these values:
spec:
  gcpCredentials:
    projectName: YOUR_PROJECT_ID  # Replace with your GCP project ID
    region: YOUR_REGION         # Replace with your preferred region
```

Apply the configuration:

```bash
# Apply GCP Vertex AI backend configuration
kubectl apply -f gcp_vertex.yaml

# Apply GCP Vertex AI broken backend Configurtion
kubectl apply -f gcp_vertex_broken.yaml 

# Verify all resources are created
kubectl get aiservicebackend,backendsecuritypolicy,backend,aigatewayroute -n default
```

### 3.4 Apply Backend TLS Policy

The `BackendTLSPolicy` is required to establish secure HTTPS connections to GCP's API endpoints:

```bash
# Apply TLS policies for GCP backends
kubectl apply -f Backend-tls-policy.yaml

# Verify TLS policies are applied
kubectl get backendtlspolicy -n default
```

### 3.5 Verify Configuration Status

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

## Part 4: Testing the Integration

### 4.1 Configure Port Forwarding

```bash
# Get the Envoy service name
export ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system \
  --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')

# Port forward to access the gateway
kubectl port-forward -n envoy-gateway-system svc/$ENVOY_SERVICE 8080:80
```
**Test the working GCP Model First**

```bash
# In another terminal, set the gateway URL
export GATEWAY_URL="http://localhost:8080"
curl -v -H "Content-Type: application/json" \
  -d '{
    "model": "vertex-virtual-model",
    "messages": [
      {"role": "user", "content": "What is cloud computing?"}
    ]
  }' \
  $GATEWAY_URL/v1/chat/completions

```

**Note:** If you are working with Multipass, use:
```bash
kubectl port-forward --address 0.0.0.0 -n envoy-gateway-system svc/$ENVOY_SERVICE 8080:80
```

Then access the gateway using your VM's IP address.

### 4.2 Test Fallback Mechanism

The configuration includes a deliberately broken primary backend (`envoy-ai-gateway-gcp-broken`) that points to a non-existent hostname. This demonstrates the automatic fallback to the working backend.

**Switch  to broken backend in gcp_vertex.yaml file for the primary model**
**Expected Configuration**
```bash
kubectl patch aigatewayroute envoy-ai-gateway-fallback -n default --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/rules/0/backendRefs",
    "value": [
      {
        "name": "envoy-ai-gateway-gcp-broken",
        "modelNameOverride": "gemini-2.5-pro",
        "priority": 0
      },
      {
        "name": "envoy-ai-gateway-basic-gcp",
        "modelNameOverride": "gemini-2.5-flash",
        "priority": 1
      }
    ]
  }
]'
```
**verified if the patch worked**
```bash
kubectl describe aigatewayroute envoy-ai-gateway-fallback -n default 
```
**You should get something like this  where the backend name has been replaced with "envoy-ai-gateway-gcp-broken"**

```bash
 Backend Refs:
      Model Name Override:  gemini-2.5-pro
      Name:                 envoy-ai-gateway-gcp-broken
      Priority:             0
   
```
**Test Fallback**
```bash
kubectl apply -f gcp_vertex.yaml
# Test the virtual model - should fallback to working backend
curl -v -H "Content-Type: application/json" \
  -d '{
    "model": "vertex-virtual-model",
    "messages": [
      {"role": "user", "content": "What is cloud computing?"}
    ]
  }' \
  $GATEWAY_URL/v1/chat/completions
```

**Expected Behavior:**
1. First attempt: Routes to `envoy-ai-gateway-gcp-broken` (Priority 0) with `gemini-2.5-pro`
2. Connection fails due to non-existent hostname
3. Gateway automatically retries with `envoy-ai-gateway-basic-gcp` (Priority 1) with `gemini-2.5-flash`
4. Request succeeds and returns response; In other words it is the `gemini-2.5-flash` that receives the request and responds intead of the `gemini-2.5-pro`.




### 4.3 Monitor Gateway Logs

Watch the logs to see the retry and fallback mechanism in action:

```bash
# View gateway logs
POD_NAME=$(kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic -o jsonpath='{.items[0].metadata.name}')

# Follow logs in real-time
kubectl logs -n envoy-gateway-system $POD_NAME -f

# In another terminal, make requests and observe the logs
```

You should see log entries showing:
- Initial connection attempt to the broken backend
- Connection failure
- Retry attempt to the fallback backend
- Successful response

**Example of Output**
```bash
{":authority":"us-central1-aiplatform.googleapis.com","bytes_received":166,"bytes_sent":7248,"connection_termination_details":null,"downstream_local_address":"127.0.0.1:10080","downstream_remote_address":"127.0.0.1:38676","duration":24939,"method":"POST","protocol":"HTTP/1.1","requested_server_name":null,"response_code":200,"response_code_details":"via_upstream","response_flags":"-","route_name":"httproute/default/envoy-ai-gateway-fallback/rule/0/match/0/*","start_time":"2026-01-14T09:10:53.669Z","upstream_cluster":"httproute/default/envoy-ai-gateway-fallback/rule/0","upstream_host":"142.250.179.74:443","upstream_local_address":"10.42.0.13:32968","upstream_transport_failure_reason":null,"user-agent":"curl/8.5.0","x-envoy-origin-path":"/v1/projects/kivoyo/locations/us-central1/publishers/google/models/gemini-2.5-pro:streamGenerateContent?alt=sse","x-envoy-upstream-service-time":null,"x-forwarded-for":"10.42.0.13","x-request-id":"1997f95e-a64d-48b5-b0b1-6e8b08a5c1e5"}
```

### 4.5 Test Streaming Responses

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


## Part 5 : Monitoring and Observability With Phoenix

**Check if the ext_proc filter is being inserted:**
```sh
kubectl logs -n envoy-ai-gateway-system deployment/ai-gateway-controller \
| grep "inserting AI Gateway extproc"
```
If you see output like inserting AI Gateway extproc filter into listener, the fix worked.

**Verify OTEL env vars are in the sidecar:**

For k3s
```sh
ENVOY_POD=$(kubectl get pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic -o jsonpath='{.items[0].metadata.name}')
kubectl get pod -n envoy-gateway-system $ENVOY_POD -o json | jq '.spec.initContainers[] | select(.name=="ai-gateway-extproc") | .env'
```
For k3d
```sh
ENVOY_POD=$(kubectl get pods -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic \
  -o jsonpath='{.items[0].metadata.name}')

kubectl get pod -n envoy-gateway-system "$ENVOY_POD" -o json \
| jq '.spec.containers[] | select(.name=="ai-gateway-extproc") | .env'
```
You should see OTEL_EXPORTER_OTLP_ENDPOINT in the output.

Set the gateway URL:
```sh
export GATEWAY_URL="http://localhost:8080"

# Send 5 test requests
for i in 1 2 3 4 5; do
  echo "Request $i:"
  curl -v -H "Content-Type: application/json" \
    -d '{
      "model": "vertex-virtual-model",
      "messages": [
        {"role": "user", "content": "Explain AI in one sentence."}
      ]
    }' \
    $GATEWAY_URL/v1/chat/completions
  echo -e "\n---\n"
done
```
  It should return 200 OK with some model response

**Check Phoenix is receiving traces**
```sh
kubectl logs -n envoy-ai-gateway-system deployment/phoenix | grep "POST /v1/traces"
```
You should get 
```text
kubectl logs -n envoy-ai-gateway-system deployment/phoenix | grep "POST /v1/traces"
INFO:     10.42.0.27:44010 - "POST /v1/traces HTTP/1.1" 200 OK
INFO:     10.42.0.27:54288 - "POST /v1/traces HTTP/1.1" 200 OK
INFO:     10.42.0.27:45630 - "POST /v1/traces HTTP/1.1" 200 OK
INFO:     10.42.0.27:37096 - "POST /v1/traces HTTP/1.1" 200 OK
INFO:     10.42.0.27:33760 - "POST /v1/traces HTTP/1.1" 200 OK
```
**Access Phoenix UI**
Port-forward to access the Phoenix dashboard:
```sh
kubectl port-forward -n envoy-ai-gateway-system svc/phoenix-svc 6006:6006
```
Then open http://localhost:6006 in your browser to explore the traces.

Run as many requests as you wish and notice the changes in the phoenix UI

## Troubleshooting
 Just in case 
 ```bash
 # Restart AI Gateway controller first
kubectl rollout restart deployment -n envoy-ai-gateway-system ai-gateway-controller

   # Wait for it to be ready

kubectl rollout status deployment -n envoy-ai-gateway-system ai-gateway-controller

    # Delete Envoy pods to force recreation

kubectl delete pods -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic

    # Wait for new pods

kubectl wait --for=condition=Ready -n envoy-gateway-system \
    pods -l gateway.envoyproxy.io/owning-gateway-name=envoy-ai-gateway-basic --timeout=60s
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
k3d cluster delete <cluster-name>
```




