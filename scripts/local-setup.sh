#!/bin/bash
set -e

# Heimdall Local Development Setup Script
# Sets up kind cluster with MetalLB + Traefik + Heimdall for local OAuth testing

echo "=== Heimdall Local Development Setup ==="
echo ""

# Check prerequisites
command -v kind >/dev/null 2>&1 || { echo "Error: kind not installed. Run: brew install kind"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl not installed. Run: brew install kubectl"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "Error: helm not installed. Run: brew install helm"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "Error: jq not installed. Run: brew install jq"; exit 1; }

# Configuration
CLUSTER_NAME=${CLUSTER_NAME:-heimdall-dev}
IMAGE_REPO=${IMAGE_REPO:-heimdall-app}
IMAGE_TAG=${IMAGE_TAG:-arm64-test}
NAMESPACE=${NAMESPACE:-heimdall}

echo "Configuration:"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Image: $IMAGE_REPO:$IMAGE_TAG"
echo "  Namespace: $NAMESPACE"
echo ""

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
    echo "Cluster '$CLUSTER_NAME' already exists."
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing cluster..."
        kind delete cluster --name "$CLUSTER_NAME"
    else
        echo "Using existing cluster."
        SKIP_CLUSTER=true
    fi
fi

if [ "$SKIP_CLUSTER" != "true" ]; then
    echo "=== Creating kind cluster with ingress support ==="
    cat <<EOF | kind create cluster --name "$CLUSTER_NAME" --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
fi

echo ""
echo "=== Installing MetalLB ==="
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml

echo "Waiting for MetalLB to be ready..."
kubectl wait --namespace metallb-system \
    --for=condition=ready pod \
    --selector=app=metallb \
    --timeout=90s

echo ""
echo "=== Configuring MetalLB IP pool ==="
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: heimdall-pool
  namespace: metallb-system
spec:
  addresses:
  - 172.18.255.200-172.18.255.250
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: heimdall-l2
  namespace: metallb-system
EOF

echo ""
echo "=== Installing Traefik ==="
helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1

helm upgrade --install traefik traefik/traefik \
    --namespace traefik --create-namespace \
    --set "ports.web.redirectTo.port=websecure" \
    --set "ports.websecure.tls.enabled=true"

echo "Waiting for Traefik to be ready..."
kubectl wait --namespace traefik \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=traefik \
    --timeout=90s

# Get LoadBalancer IP
echo "Waiting for LoadBalancer IP assignment..."
for i in {1..30}; do
    INGRESS_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    if [ -n "$INGRESS_IP" ]; then
        break
    fi
    sleep 2
done

if [ -z "$INGRESS_IP" ]; then
    echo "Error: LoadBalancer IP not assigned after 60 seconds"
    echo "Check MetalLB configuration:"
    echo "  kubectl get ipaddresspool -n metallb-system"
    echo "  kubectl logs -n metallb-system -l app=metallb"
    exit 1
fi

echo "Traefik LoadBalancer IP: $INGRESS_IP"

echo ""
echo "=== Loading Heimdall ARM64 image to kind ==="
if docker images | grep -q "$IMAGE_REPO.*$IMAGE_TAG"; then
    kind load docker-image "$IMAGE_REPO:$IMAGE_TAG" --name "$CLUSTER_NAME"
else
    echo "Warning: Image $IMAGE_REPO:$IMAGE_TAG not found locally"
    echo "Helm will try to pull from registry (may fail if not available)"
fi

echo ""
echo "=== Installing Heimdall ==="
helm upgrade --install heimdall ./heimdall \
    --namespace "$NAMESPACE" --create-namespace \
    --set heimdall.image.repository="$IMAGE_REPO" \
    --set heimdall.image.tag="$IMAGE_TAG" \
    --set heimdall.ingress.enabled=true \
    --set heimdall.ingress.className=traefik \
    --set "heimdall.ingress.hosts[0].host=heimdall.${INGRESS_IP}.nip.io" \
    --set "heimdall.ingress.hosts[0].paths[0].path=/" \
    --set "heimdall.ingress.hosts[0].paths[0].pathType=Prefix" \
    --set externalUrl="http://heimdall.${INGRESS_IP}.nip.io"

echo "Waiting for Heimdall pods to be ready..."
kubectl wait --namespace "$NAMESPACE" \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/name=heimdall \
    --timeout=180s

echo ""
echo "=========================================="
echo "=== Setup Complete! ==="
echo "=========================================="
echo ""
echo "Heimdall URL: http://heimdall.${INGRESS_IP}.nip.io"
echo ""
echo "OAuth Callback URLs (use these in provider config):"
echo "  GitLab: http://heimdall.${INGRESS_IP}.nip.io/authn/gitlab/callback"
echo "  GitHub: http://heimdall.${INGRESS_IP}.nip.io/authn/github/callback"
echo "  Google: http://heimdall.${INGRESS_IP}.nip.io/authn/google/callback"
echo "  Okta:   http://heimdall.${INGRESS_IP}.nip.io/authn/okta/callback"
echo ""
echo "Useful commands:"
echo "  View logs:       kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=heimdall -f"
echo "  Check pods:      kubectl get pods -n $NAMESPACE"
echo "  Check ingress:   kubectl get ingress -n $NAMESPACE"
echo "  Port-forward DB: kubectl port-forward -n $NAMESPACE svc/heimdall-postgresql 5432:5432"
echo "  Delete cluster:  kind delete cluster --name $CLUSTER_NAME"
echo ""
