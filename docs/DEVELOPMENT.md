# Development Environment Setup

This guide covers setting up a local development environment for Heimdall Helm chart development and testing.

## Prerequisites

### Required Tools

#### Helm v4.x (or v3.12+)

```bash
# Check current version
helm version

# Should show: version.BuildInfo{Version:"v4.0.0"...} or v3.12+

# Install/Upgrade Helm
# macOS
brew install helm
brew upgrade helm

# Linux
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Windows (using Chocolatey)
choco install kubernetes-helm
```

**Helm v4 Benefits**:
- Server-Side Apply (SSA) by default
- WebAssembly plugin support
- Enhanced security features
- Backward compatible with v3 charts

#### kubectl

```bash
# Check version
kubectl version --client

# Install
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Windows (using Chocolatey)
choco install kubernetes-cli
```

#### Kubernetes Cluster

**Options**:
1. **kind** (Kubernetes in Docker) - Recommended for local development
2. **minikube** - Alternative local cluster
3. **Docker Desktop** - Built-in Kubernetes (macOS/Windows)
4. **Cloud cluster** - GKE, EKS, AKS (for production-like testing)

#### Beads Task Tracker

```bash
# Check if installed
bd --version

# Install (macOS)
brew install steveyegge/beads/bd

# Install (Linux)
# Download from https://github.com/steveyegge/beads/releases
```

### Optional Tools

```bash
# Helm plugins
helm plugin install https://github.com/databus23/helm-diff
helm plugin install https://github.com/jkroepke/helm-secrets

# k9s (Kubernetes CLI UI)
brew install k9s  # macOS
# Or download from https://github.com/derailed/k9s/releases

# kubectx/kubens (context switching)
brew install kubectx  # macOS

# yamllint (YAML validation)
brew install yamllint  # macOS
pip install yamllint   # Linux/Windows
```

## Local Kubernetes Cluster Setup

### Option 1: kind (Recommended)

**Why kind?**
- Fast cluster creation/deletion
- Multiple cluster support
- Ingress controller support
- Close to production Kubernetes

#### Basic kind Cluster

```bash
# Install kind
# macOS
brew install kind

# Linux
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Create cluster
kind create cluster --name heimdall-dev

# Verify cluster
kubectl cluster-info --context kind-heimdall-dev
kubectl get nodes
```

#### kind Cluster with Ingress Support

```bash
# Create cluster with ingress configuration
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
- role: worker
- role: worker
EOF

# Install NGINX Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress controller ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

# Verify ingress
kubectl get pods -n ingress-nginx
```

#### kind Cluster Management

```bash
# List clusters
kind get clusters

# Delete cluster
kind delete cluster --name heimdall-dev

# Export kubeconfig
kind export kubeconfig --name heimdall-dev

# Load local image into cluster (for testing)
kind load docker-image mitre/heimdall2:local --name heimdall-dev
```

### Option 2: minikube

```bash
# Install minikube
# macOS
brew install minikube

# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# Start cluster
minikube start --cpus=4 --memory=8192 --driver=docker

# Enable ingress
minikube addons enable ingress

# Enable metrics server
minikube addons enable metrics-server

# Access cluster
kubectl get nodes

# Stop cluster
minikube stop

# Delete cluster
minikube delete
```

### Option 3: Docker Desktop

```bash
# Enable Kubernetes in Docker Desktop settings
# Settings → Kubernetes → Enable Kubernetes → Apply & Restart

# Switch context
kubectl config use-context docker-desktop

# Verify
kubectl get nodes
```

## Project Setup

### Clone Repository

```bash
# Clone heimdall-helm
cd ~/github/mitre
git clone https://github.com/mitre/heimdall-helm.git
cd heimdall-helm

# Initialize Beads (if not already initialized)
bd init

# Check ready tasks
bd ready
```

### Reference Vulcan Chart

The Vulcan Helm chart serves as the reference implementation:

```bash
# Clone vulcan-helm (if not already cloned)
cd ~/github/mitre
git clone https://github.com/mitre/vulcan-helm.git

# Keep both repositories side-by-side:
# ~/github/mitre/heimdall-helm  (current work)
# ~/github/mitre/vulcan-helm    (reference patterns)
```

### Install Chart Dependencies

```bash
# Navigate to chart directory
cd ~/github/mitre/heimdall-helm

# Update Helm dependencies (downloads Bitnami PostgreSQL)
helm dependency update ./heimdall

# Verify dependencies
helm dependency list ./heimdall

# Build dependencies from Chart.lock
helm dependency build ./heimdall
```

## Development Workflow

### 1. Chart Validation

```bash
# Lint chart (checks syntax and best practices)
helm lint ./heimdall

# Strict lint (fails on warnings)
helm lint ./heimdall --strict

# Template rendering (preview manifests)
helm template heimdall ./heimdall

# Template with debug output
helm template heimdall ./heimdall --debug

# Validate YAML syntax
helm template heimdall ./heimdall | kubectl apply --dry-run=client -f -
```

### 2. Local Testing

```bash
# Generate secrets
./generate-heimdall-secrets.sh

# Install to local cluster
helm install heimdall ./heimdall -n heimdall --create-namespace

# Watch deployment
watch -n 2 kubectl get pods -n heimdall

# Check logs
kubectl logs -n heimdall statefulset/heimdall -f

# Port forward to access locally
kubectl port-forward -n heimdall statefulset/heimdall 3000:3000

# Access in browser: http://localhost:3000
```

### 3. Iterative Development

```bash
# Make changes to templates
vim heimdall/templates/heimdall-statefulset.yaml

# Lint changes
helm lint ./heimdall --strict

# Upgrade deployment (applies changes)
helm upgrade heimdall ./heimdall -n heimdall

# Or use upgrade --install (idempotent)
helm upgrade --install heimdall ./heimdall -n heimdall

# Verify upgrade
kubectl rollout status statefulset/heimdall -n heimdall
kubectl get pods -n heimdall
```

### 4. Testing Different Configurations

```bash
# Test with external database
helm install heimdall ./heimdall -n heimdall-extdb \
  --set postgresql.enabled=false \
  --set externalDatabase.host=postgres.example.com \
  --create-namespace

# Test with ingress enabled
helm install heimdall ./heimdall -n heimdall-ingress \
  --set heimdall.ingress.enabled=true \
  --set heimdall.ingress.hosts[0].host=localhost \
  --create-namespace

# Test with custom values file
helm install heimdall ./heimdall -n heimdall-custom \
  -f test-values.yaml \
  --create-namespace
```

### 5. Cleanup

```bash
# Uninstall release
helm uninstall heimdall -n heimdall

# Delete namespace (and all resources)
kubectl delete namespace heimdall

# Or clean up all test namespaces
kubectl delete namespace heimdall-extdb heimdall-ingress heimdall-custom
```

## Debugging Techniques

### Template Debugging

```bash
# Show specific template
helm template heimdall ./heimdall --show-only templates/heimdall-statefulset.yaml

# Check value interpolation
helm template heimdall ./heimdall --debug | grep -A 5 "DATABASE_HOST"

# Render with custom values
helm template heimdall ./heimdall \
  --set heimdall.replicaCount=5 \
  --set postgresql.enabled=false \
  --debug
```

### Pod Debugging

```bash
# Describe pod (check events, status)
kubectl describe pod -n heimdall heimdall-0

# Check logs
kubectl logs -n heimdall heimdall-0 -f

# Check previous container logs (after crash)
kubectl logs -n heimdall heimdall-0 --previous

# Execute commands in pod
kubectl exec -n heimdall -it heimdall-0 -- /bin/sh

# Inside pod:
env | grep DATABASE
node --version
npm --version
ls -la /app
```

### PostgreSQL Debugging

```bash
# Connect to PostgreSQL
kubectl exec -n heimdall -it heimdall-postgresql-0 -- psql -U postgres

# Inside psql:
\l                          # List databases
\c heimdall                 # Connect to database
\dt                         # List tables
\d SequelizeMeta            # Show migrations table
SELECT * FROM "SequelizeMeta";  # Check applied migrations
\q                          # Quit

# Get PostgreSQL password
kubectl get secret -n heimdall heimdall-postgresql \
  -o jsonpath="{.data.postgres-password}" | base64 -d
```

### Network Debugging

```bash
# Test service connectivity
kubectl run -n heimdall test-pod --rm -i --tty \
  --image=nicolaka/netshoot -- /bin/bash

# Inside test pod:
curl http://heimdall:3000
curl http://heimdall-postgresql:5432
nslookup heimdall
nslookup heimdall-postgresql
exit

# Test ingress (if enabled)
curl -H "Host: heimdall.local" http://localhost
```

### Resource Debugging

```bash
# Check resource usage
kubectl top pods -n heimdall
kubectl top nodes

# Check events
kubectl get events -n heimdall --sort-by='.lastTimestamp'

# Check all resources
kubectl get all,configmap,secret,ingress,pvc -n heimdall

# Check PVC status
kubectl get pvc -n heimdall
kubectl describe pvc -n heimdall data-heimdall-postgresql-0
```

## IDE Setup (Optional)

### VS Code Extensions

Recommended extensions for Helm chart development:

```bash
# Install VS Code extensions
code --install-extension ms-kubernetes-tools.vscode-kubernetes-tools
code --install-extension redhat.vscode-yaml
code --install-extension Tim-Koehler.helm-intellisense
```

### YAML Linting

Create `.yamllint` in project root:

```yaml
---
extends: default

rules:
  line-length:
    max: 120
    level: warning
  indentation:
    spaces: 2
    indent-sequences: consistent
  comments:
    min-spaces-from-content: 1
```

## Testing Tools

### Helm Unit Tests (Optional)

```bash
# Install helm-unittest plugin
helm plugin install https://github.com/helm-unittest/helm-unittest

# Run tests
helm unittest ./heimdall

# Generate test coverage
helm unittest ./heimdall --with-subchart --output-file test-results.xml
```

### Kubernetes Test Pods

Create test pods for connectivity testing:

```bash
# Create test-connection.yaml in heimdall/templates/tests/
cat <<EOF > heimdall/templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "heimdall.fullname" . }}-test-connection
  labels:
    {{- include "heimdall.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
spec:
  containers:
    - name: wget
      image: busybox
      command: ['wget']
      args: ['{{ include "heimdall.fullname" . }}:3000']
  restartPolicy: Never
EOF

# Run test
helm test heimdall -n heimdall
```

## Common Development Tasks

### Update Chart Dependencies

```bash
# Update to latest Bitnami PostgreSQL
helm dependency update ./heimdall

# Review changes
git diff heimdall/Chart.lock

# Commit if intentional
git add heimdall/Chart.lock
git commit -m "chore: update PostgreSQL subchart to v18.3.0"
```

### Regenerate Secrets

```bash
# Delete old secrets file
rm heimdall/env/heimdall-secrets.yaml

# Generate new secrets
./generate-heimdall-secrets.sh

# Verify secrets file
cat heimdall/env/heimdall-secrets.yaml  # Should show new random values
```

### Test Upgrade Path

```bash
# Install v3.3.3 (old version)
helm install heimdall ./heimdall-old -n heimdall

# Upgrade to v1.0.0 (new version)
helm upgrade heimdall ./heimdall -n heimdall

# Verify upgrade
helm history heimdall -n heimdall
kubectl get pods -n heimdall
```

### Package Chart for Testing

```bash
# Package chart
helm package ./heimdall

# Verify package
helm lint heimdall-1.0.0.tgz

# Install from package
helm install heimdall heimdall-1.0.0.tgz -n heimdall
```

## Performance Tips

### Speed Up Development Cycle

```bash
# Use --wait=false for faster testing
helm upgrade heimdall ./heimdall -n heimdall --wait=false

# Skip hooks for faster iteration
helm upgrade heimdall ./heimdall -n heimdall --no-hooks

# Use template for syntax checks (no cluster needed)
helm template heimdall ./heimdall | head -100

# Use dry-run for quick validation
helm upgrade heimdall ./heimdall -n heimdall --dry-run --debug | less
```

### Optimize PostgreSQL for Development

```yaml
# Use minimal resources for faster startup
postgresql:
  primary:
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
      limits:
        cpu: 200m
        memory: 256Mi
    persistence:
      enabled: false  # Faster startup, data lost on restart
```

## Troubleshooting Development Issues

### "Error: Kubernetes cluster unreachable"

```bash
# Check cluster status
kubectl cluster-info

# Check context
kubectl config current-context

# Switch to correct context
kubectl config use-context kind-heimdall-dev

# Restart Docker (if using Docker Desktop)
```

### "Error: INSTALLATION FAILED: chart requires kubeVersion"

```bash
# Check Kubernetes version
kubectl version --short

# Update Chart.yaml kubeVersion constraint if needed
# kubeVersion: ">=1.20.0"
```

### "Error: cannot re-use a name that is still in use"

```bash
# Uninstall existing release
helm uninstall heimdall -n heimdall

# Or use different release name
helm install heimdall-test ./heimdall -n heimdall
```

### PostgreSQL Won't Start

```bash
# Check PVC status
kubectl get pvc -n heimdall

# Check PV provisioning
kubectl get pv

# For kind, ensure StorageClass exists
kubectl get storageclass

# Delete PVC and recreate
kubectl delete pvc -n heimdall data-heimdall-postgresql-0
helm upgrade heimdall ./heimdall -n heimdall
```

## Best Practices

### Development Workflow

1. **Always lint before committing**: `helm lint ./heimdall --strict`
2. **Test locally before PR**: Install to kind cluster and verify
3. **Use --dry-run for validation**: Preview changes before applying
4. **Keep dependencies updated**: Regular `helm dependency update`
5. **Document changes**: Update CHANGELOG.md and SESSION-*.md

### Git Workflow

1. **Create feature branches**: `git checkout -b feat/new-feature`
2. **Commit often**: Small, focused commits
3. **Use conventional commits**: `feat:`, `fix:`, `docs:`, `chore:`
4. **Test before pushing**: Ensure all tests pass
5. **Update Beads tasks**: Mark tasks complete with `bd done <task-id>`

### Chart Development

1. **Reference Vulcan patterns**: Don't reinvent, adapt proven solutions
2. **Test both embedded and external DB**: Both configurations should work
3. **Validate with values.schema.json**: Catch configuration errors early
4. **Use template helpers**: DRY principle for common patterns
5. **Document complex logic**: Comments in templates for future maintainers

## References

- [kind Documentation](https://kind.sigs.k8s.io/)
- [minikube Documentation](https://minikube.sigs.k8s.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [kubectl Reference](https://kubernetes.io/docs/reference/kubectl/)
- [Beads Documentation](https://github.com/steveyegge/beads)
