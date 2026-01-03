# Heimdall Local Development - Quick Setup Guide

**Goal**: Get Heimdall running locally with stable URLs for OAuth testing
**Time**: 15-20 minutes (one-time setup)
**Platform**: kind cluster on macOS (also works on Linux)

## Prerequisites

```bash
# Install required tools
brew install kind kubectl helm jq

# Verify installation
kind version
kubectl version --client
helm version
```

## Option 1: Full Setup (Ingress + OAuth Support) - RECOMMENDED

This gives you stable URLs like `http://heimdall.172.18.255.200.nip.io` that work with OAuth providers.

### Step 1: Create kind Cluster with Ingress Ports

```bash
cat <<EOF | kind create cluster --name heimdall-dev --config=-
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
```

### Step 2: Install MetalLB

```bash
# Install MetalLB
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml

# Wait for MetalLB to be ready
kubectl wait --namespace metallb-system \
  --for=condition=ready pod \
  --selector=app=metallb \
  --timeout=90s
```

### Step 3: Configure MetalLB IP Pool

```bash
# Get kind cluster's Docker network CIDR
CIDR=$(docker network inspect kind | jq -r '.[0].IPAM.Config[0].Subnet')
echo "Kind cluster CIDR: $CIDR"

# Create IP pool from cluster CIDR range
# Using .255.200-250 range to avoid conflicts
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
```

### Step 4: Install Traefik Ingress Controller

```bash
# Add Traefik Helm repository
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Install Traefik
helm upgrade --install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --set "ports.web.redirectTo.port=websecure" \
  --set "ports.websecure.tls.enabled=true"

# Wait for LoadBalancer IP assignment
echo "Waiting for Traefik LoadBalancer IP..."
kubectl wait --namespace traefik \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=traefik \
  --timeout=90s

# Get the LoadBalancer IP
INGRESS_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Traefik LoadBalancer IP: $INGRESS_IP"
```

### Step 5: Load Heimdall ARM64 Image to kind

```bash
# Load pre-built ARM64 image
kind load docker-image heimdall-app:arm64-test --name heimdall-dev

# Verify image loaded
docker exec heimdall-dev-control-plane crictl images | grep heimdall
```

### Step 6: Install Heimdall with Ingress

```bash
# Get LoadBalancer IP (if not in same shell session)
INGRESS_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Create namespace
kubectl create namespace heimdall

# Install Heimdall
helm upgrade --install heimdall ./heimdall \
  --namespace heimdall \
  --set heimdall.image.repository=heimdall-app \
  --set heimdall.image.tag=arm64-test \
  --set heimdall.ingress.enabled=true \
  --set heimdall.ingress.className=traefik \
  --set "heimdall.ingress.hosts[0].host=heimdall.${INGRESS_IP}.nip.io" \
  --set "heimdall.ingress.hosts[0].paths[0].path=/" \
  --set "heimdall.ingress.hosts[0].paths[0].pathType=Prefix" \
  --set externalUrl="http://heimdall.${INGRESS_IP}.nip.io"

# Wait for pods to be ready
kubectl wait --namespace heimdall \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=heimdall \
  --timeout=180s
```

### Step 7: Access Heimdall

```bash
# Get the full URL
INGRESS_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Heimdall URL: http://heimdall.${INGRESS_IP}.nip.io"

# Open in browser
open "http://heimdall.${INGRESS_IP}.nip.io"
```

### OAuth Callback URLs

For OAuth provider configuration, use:
```
GitLab: http://heimdall.172.18.255.200.nip.io/authn/gitlab/callback
GitHub: http://heimdall.172.18.255.200.nip.io/authn/github/callback
Google: http://heimdall.172.18.255.200.nip.io/authn/google/callback
Okta:   http://heimdall.172.18.255.200.nip.io/authn/okta/callback
```

Replace `172.18.255.200` with your actual LoadBalancer IP from Step 7.

---

## Option 2: Quick Test (Port Forward) - NO OAuth

This is faster but doesn't support OAuth providers (localhost URLs won't work).

### Setup

```bash
# Create basic kind cluster
kind create cluster --name heimdall-test

# Install Heimdall
helm install heimdall ./heimdall -n heimdall --create-namespace

# Wait for pods
kubectl wait --namespace heimdall \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=heimdall \
  --timeout=180s

# Port-forward to localhost
kubectl port-forward -n heimdall svc/heimdall 8080:3000
```

### Access

```bash
# Open browser
open http://localhost:8080
```

**Limitations**:
- No OAuth support (providers reject localhost callbacks)
- Port-forward breaks when pod restarts
- Not production-like

---

## Verification Commands

```bash
# Check all pods are running
kubectl get pods -n heimdall
kubectl get pods -n traefik

# Check services
kubectl get svc -n heimdall
kubectl get svc -n traefik

# Check ingress
kubectl get ingress -n heimdall

# View Heimdall logs
kubectl logs -n heimdall -l app.kubernetes.io/name=heimdall -f

# Check database
kubectl logs -n heimdall -l app.kubernetes.io/name=postgresql
```

---

## Troubleshooting

### LoadBalancer IP stuck in "Pending"

```bash
# Check MetalLB logs
kubectl logs -n metallb-system -l app=metallb

# Verify IP pool configuration
kubectl get ipaddresspool -n metallb-system -o yaml
```

### Heimdall pod not starting

```bash
# Check pod events
kubectl describe pod -n heimdall -l app.kubernetes.io/name=heimdall

# Check logs
kubectl logs -n heimdall -l app.kubernetes.io/name=heimdall

# Common issue: Image not loaded to kind
kind load docker-image heimdall-app:arm64-test --name heimdall-dev
```

### Ingress returns 404

```bash
# Check ingress configuration
kubectl get ingress -n heimdall -o yaml

# Check Traefik routes
kubectl port-forward -n traefik svc/traefik 9000:9000
open http://localhost:9000/dashboard/
```

### Database connection issues

```bash
# Check PostgreSQL pod
kubectl get pods -n heimdall -l app.kubernetes.io/name=postgresql

# Check database logs
kubectl logs -n heimdall heimdall-postgresql-0

# Get auto-generated password
kubectl get secret -n heimdall heimdall-postgresql \
  -o jsonpath="{.data.postgres-password}" | base64 -d && echo
```

---

## Cleanup

```bash
# Delete Heimdall release
helm uninstall heimdall -n heimdall

# Delete namespaces
kubectl delete namespace heimdall
kubectl delete namespace traefik
kubectl delete namespace metallb-system

# Delete kind cluster
kind delete cluster --name heimdall-dev
```

---

## One-Liner Setup Script

Save this as `scripts/local-setup.sh`:

```bash
#!/bin/bash
set -e

echo "=== Creating kind cluster with ingress support ==="
cat <<EOF | kind create cluster --name heimdall-dev --config=-
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
  - containerPort: 443
    hostPort: 443
EOF

echo "=== Installing MetalLB ==="
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml
kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s

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

echo "=== Installing Traefik ==="
helm repo add traefik https://traefik.github.io/charts
helm repo update
helm upgrade --install traefik traefik/traefik \
  --namespace traefik --create-namespace \
  --set "ports.web.redirectTo.port=websecure" \
  --set "ports.websecure.tls.enabled=true"

kubectl wait --namespace traefik --for=condition=ready pod --selector=app.kubernetes.io/name=traefik --timeout=90s

echo "=== Loading Heimdall ARM64 image ==="
kind load docker-image heimdall-app:arm64-test --name heimdall-dev

INGRESS_IP=$(kubectl get svc -n traefik traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "=== Installing Heimdall ==="
helm upgrade --install heimdall ./heimdall \
  --namespace heimdall --create-namespace \
  --set heimdall.image.repository=heimdall-app \
  --set heimdall.image.tag=arm64-test \
  --set heimdall.ingress.enabled=true \
  --set heimdall.ingress.className=traefik \
  --set "heimdall.ingress.hosts[0].host=heimdall.${INGRESS_IP}.nip.io" \
  --set "heimdall.ingress.hosts[0].paths[0].path=/" \
  --set "heimdall.ingress.hosts[0].paths[0].pathType=Prefix" \
  --set externalUrl="http://heimdall.${INGRESS_IP}.nip.io"

kubectl wait --namespace heimdall --for=condition=ready pod --selector=app.kubernetes.io/name=heimdall --timeout=180s

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Heimdall URL: http://heimdall.${INGRESS_IP}.nip.io"
echo ""
echo "OAuth Callback URLs:"
echo "  GitLab: http://heimdall.${INGRESS_IP}.nip.io/authn/gitlab/callback"
echo "  GitHub: http://heimdall.${INGRESS_IP}.nip.io/authn/github/callback"
echo "  Google: http://heimdall.${INGRESS_IP}.nip.io/authn/google/callback"
echo ""
```

Make executable and run:
```bash
chmod +x scripts/local-setup.sh
./scripts/local-setup.sh
```

---

## Next Steps

1. **Configure OAuth providers** with callback URLs from Step 7
2. **Test authentication flows** with actual OAuth providers
3. **Load test data** (InSpec profiles, security scans)
4. **Test chart upgrades** with different values configurations

---

## Reference

For detailed explanations and alternatives, see:
- [LOCAL-ACCESS-RECOMMENDATIONS.md](./LOCAL-ACCESS-RECOMMENDATIONS.md) - Full research and comparison
- [docs/content/4.helm-chart/local-development.md](./docs/content/4.helm-chart/local-development.md) - User documentation

**Estimated time**:
- First-time setup: 15-20 minutes
- Subsequent setups: 5-10 minutes (cached images)
- Teardown and rebuild: 3-5 minutes
