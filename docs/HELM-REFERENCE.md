# Helm Commands Reference

This document provides comprehensive Helm command reference for working with the Heimdall chart.

## Chart Development Commands

### Linting and Validation

```bash
# Basic lint (checks syntax and structure)
helm lint ./heimdall

# Strict lint (fails on warnings)
helm lint ./heimdall --strict

# Template rendering (preview generated manifests)
helm template heimdall ./heimdall

# Template with debug output
helm template heimdall ./heimdall --debug

# Template with custom values
helm template heimdall ./heimdall -f custom-values.yaml

# Save rendered manifests for review
helm template heimdall ./heimdall > rendered-manifests.yaml

# Show only specific template
helm template heimdall ./heimdall --show-only templates/heimdall-statefulset.yaml

# Validate rendered YAML with kubectl
helm template heimdall ./heimdall | kubectl apply --dry-run=client -f -
```

### Dependency Management

```bash
# Update dependencies (downloads Bitnami PostgreSQL)
helm dependency update ./heimdall

# Build dependencies from Chart.lock
helm dependency build ./heimdall

# List chart dependencies
helm dependency list ./heimdall

# Clean dependency cache
rm -rf heimdall/charts/ heimdall/Chart.lock
helm dependency update ./heimdall
```

### Chart Packaging

```bash
# Package chart for distribution
helm package ./heimdall

# Package with specific version
helm package ./heimdall --version 1.0.0

# Verify packaged chart
helm lint heimdall-1.0.0.tgz

# Show chart information
helm show chart ./heimdall
helm show values ./heimdall
helm show readme ./heimdall
helm show all ./heimdall
```

## Installation and Deployment

### Basic Installation

```bash
# Install chart to cluster
helm install heimdall ./heimdall -n heimdall --create-namespace

# Install from packaged chart
helm install heimdall heimdall-1.0.0.tgz -n heimdall --create-namespace

# Install from remote repository
helm repo add mitre https://mitre.github.io/heimdall-helm
helm repo update
helm install heimdall mitre/heimdall -n heimdall --create-namespace

# Install with custom values file
helm install heimdall ./heimdall -n heimdall -f production-values.yaml

# Install with inline value overrides
helm install heimdall ./heimdall -n heimdall \
  --set heimdall.replicaCount=5 \
  --set heimdall.ingress.enabled=true \
  --set heimdall.ingress.hosts[0].host=heimdall.example.com

# Dry run (preview what will be installed)
helm install heimdall ./heimdall -n heimdall --dry-run --debug
```

### Upgrade Operations

```bash
# Upgrade existing installation
helm upgrade heimdall ./heimdall -n heimdall

# Upgrade with new values
helm upgrade heimdall ./heimdall -n heimdall -f updated-values.yaml

# Upgrade and wait for completion
helm upgrade heimdall ./heimdall -n heimdall --wait --timeout 10m

# Upgrade with dry-run (preview changes)
helm upgrade heimdall ./heimdall -n heimdall --dry-run --debug

# Install or upgrade (idempotent)
helm upgrade --install heimdall ./heimdall -n heimdall

# Force upgrade (recreate resources)
helm upgrade heimdall ./heimdall -n heimdall --force
```

### Uninstall

```bash
# Uninstall release
helm uninstall heimdall -n heimdall

# Uninstall and keep history for rollback
helm uninstall heimdall -n heimdall --keep-history

# Complete cleanup (chart + namespace)
helm uninstall heimdall -n heimdall
kubectl delete namespace heimdall
```

## Release Management

### Status and Information

```bash
# List installed releases
helm list -n heimdall
helm list --all-namespaces

# Get release status
helm status heimdall -n heimdall

# Get user-provided values
helm get values heimdall -n heimdall

# Get all values (including defaults)
helm get values heimdall -n heimdall --all

# Get deployed manifest
helm get manifest heimdall -n heimdall

# Get all release information
helm get all heimdall -n heimdall
```

### History and Rollback

```bash
# Show release history
helm history heimdall -n heimdall

# Rollback to previous version
helm rollback heimdall -n heimdall

# Rollback to specific revision
helm rollback heimdall 2 -n heimdall

# Rollback with dry-run
helm rollback heimdall 2 -n heimdall --dry-run
```

### Testing

```bash
# Run Helm tests
helm test heimdall -n heimdall

# Run tests with logs
helm test heimdall -n heimdall --logs
```

## Kubernetes Debugging

### Pod and Deployment

```bash
# Watch deployment progress
watch -n 2 kubectl get pods -n heimdall

# Get all resources
kubectl get all -n heimdall

# Check pod status
kubectl get pods -n heimdall
kubectl describe pod -n heimdall <pod-name>

# View logs
kubectl logs -n heimdall statefulset/heimdall -f
kubectl logs -n heimdall statefulset/heimdall-postgresql -f

# View logs from all containers
kubectl logs -n heimdall statefulset/heimdall --all-containers=true -f

# View previous container logs (after crash)
kubectl logs -n heimdall <pod-name> --previous
```

### Events and Debugging

```bash
# Check events (troubleshooting)
kubectl get events -n heimdall --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl get events -n heimdall --watch

# Describe resources
kubectl describe statefulset -n heimdall heimdall
kubectl describe service -n heimdall heimdall
kubectl describe ingress -n heimdall heimdall
```

### Port Forwarding

```bash
# Port forward to access locally
kubectl port-forward -n heimdall statefulset/heimdall 3000:3000

# Port forward to PostgreSQL
kubectl port-forward -n heimdall statefulset/heimdall-postgresql 5432:5432

# Access in browser: http://localhost:3000
```

### Resource Inspection

```bash
# Check ConfigMap
kubectl get configmap -n heimdall heimdall-config -o yaml

# Check Secrets (values are base64 encoded)
kubectl get secret -n heimdall heimdall-secrets -o yaml

# Decode secret value
kubectl get secret -n heimdall heimdall-secrets -o jsonpath="{.data.JWT_SECRET}" | base64 -d

# Check PostgreSQL password
kubectl get secret -n heimdall heimdall-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d

# Check ingress
kubectl get ingress -n heimdall
kubectl describe ingress -n heimdall heimdall
```

### Interactive Debugging

```bash
# Execute command in pod
kubectl exec -n heimdall -it heimdall-0 -- /bin/sh

# Connect to PostgreSQL
kubectl exec -n heimdall -it heimdall-postgresql-0 -- psql -U postgres -d heimdall

# Run Sequelize migrations manually
kubectl exec -n heimdall -it heimdall-0 -- npx sequelize-cli db:migrate

# Check Node.js version
kubectl exec -n heimdall heimdall-0 -- node --version

# Check environment variables
kubectl exec -n heimdall heimdall-0 -- env | grep DATABASE
```

## Repository Management

### Adding Chart Repository

```bash
# Add Helm repository
helm repo add mitre https://mitre.github.io/heimdall-helm

# Update repository index
helm repo update

# Search for charts
helm search repo mitre
helm search repo mitre/heimdall --versions

# Show chart information from repo
helm show chart mitre/heimdall
helm show values mitre/heimdall
```

### Local Chart Development

```bash
# Serve chart repository locally
helm serve --repo-path ./charts

# Package and index for local repo
helm package ./heimdall -d ./charts
helm repo index ./charts --url http://localhost:8879

# Test installation from local repo
helm repo add local http://localhost:8879
helm install heimdall local/heimdall
```

## Common Production Patterns

### External Database Configuration

```bash
# Use external PostgreSQL (AWS RDS, Cloud SQL, etc.)
helm install heimdall ./heimdall -n heimdall \
  --set postgresql.enabled=false \
  --set externalDatabase.host=db.example.com \
  --set externalDatabase.port=5432 \
  --set externalDatabase.database=heimdall_production \
  --set externalDatabase.username=heimdall_app \
  --set externalDatabase.existingSecret=heimdall-db-credentials
```

### High Availability Deployment

```bash
# HA configuration with autoscaling
helm install heimdall ./heimdall -n heimdall -f - <<EOF
heimdall:
  replicaCount: 3
  autoscaling:
    enabled: true
    minReplicas: 3
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
  podDisruptionBudget:
    enabled: true
    minAvailable: 2
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi
EOF
```

### Ingress with TLS

```bash
# Install with HTTPS ingress
helm install heimdall ./heimdall -n heimdall \
  --set heimdall.ingress.enabled=true \
  --set heimdall.ingress.className=nginx \
  --set heimdall.ingress.hosts[0].host=heimdall.example.com \
  --set heimdall.ingress.tls[0].secretName=heimdall-tls \
  --set heimdall.ingress.tls[0].hosts[0]=heimdall.example.com
```

### Custom CA Certificates

```bash
# Deploy with custom CA certificates
helm install heimdall ./heimdall -n heimdall -f - <<EOF
certs:
  enabled: true
  certificates:
    - filename: corporate-ca.crt
      contents: |
        -----BEGIN CERTIFICATE-----
        MIIDXTCCAkWgAwIBAgIJAKL0UG+mRWyoMA0GCSqGSIb3DQEBCwUAMEUxCzAJBgNV
        ...
        -----END CERTIFICATE-----
EOF
```

## Values Override Patterns

### Multiple Values Files

```bash
# Layer values files (right takes precedence)
helm install heimdall ./heimdall -n heimdall \
  -f base-values.yaml \
  -f environment-values.yaml \
  -f secrets-values.yaml
```

### Environment-Specific Deployments

```bash
# Development
helm install heimdall ./heimdall -n heimdall-dev \
  -f values/dev-values.yaml

# Staging
helm install heimdall ./heimdall -n heimdall-staging \
  -f values/staging-values.yaml

# Production
helm install heimdall ./heimdall -n heimdall-prod \
  -f values/production-values.yaml
```

### Secret Management Integration

```bash
# With External Secrets Operator
helm install heimdall ./heimdall -n heimdall \
  --set heimdall.existingSecret=heimdall-production-secrets

# With Sealed Secrets
kubeseal < heimdall-secrets.yaml > heimdall-sealed-secrets.yaml
kubectl apply -f heimdall-sealed-secrets.yaml
helm install heimdall ./heimdall -n heimdall \
  --set heimdall.existingSecret=heimdall-secrets
```

## Troubleshooting Commands

### Template Debugging

```bash
# Debug template rendering errors
helm template heimdall ./heimdall --debug 2>&1 | less

# Check specific value interpolation
helm template heimdall ./heimdall --debug | grep -A 5 "DATABASE_HOST"

# Validate generated YAML syntax
helm template heimdall ./heimdall | yamllint -
```

### Installation Issues

```bash
# Check what resources were created
kubectl get all,configmap,secret,ingress,pvc -n heimdall

# View Helm release status with hooks
helm status heimdall -n heimdall --show-resources

# Check failed hooks
kubectl get jobs -n heimdall
kubectl logs -n heimdall job/heimdall-migrate

# Delete failed job and retry
kubectl delete job -n heimdall heimdall-migrate
helm upgrade heimdall ./heimdall -n heimdall
```

### Network Debugging

```bash
# Test service connectivity
kubectl run -n heimdall test-pod --rm -i --tty --image=nicolaka/netshoot -- /bin/bash
# Inside pod: curl http://heimdall:3000

# Check DNS resolution
kubectl run -n heimdall test-dns --rm -i --tty --image=busybox -- nslookup heimdall

# Test ingress
curl -H "Host: heimdall.example.com" http://<ingress-ip>
```

### Resource Issues

```bash
# Check resource usage
kubectl top pods -n heimdall
kubectl top nodes

# Describe pod to see resource limits
kubectl describe pod -n heimdall heimdall-0 | grep -A 5 Limits

# Check PVC status
kubectl get pvc -n heimdall
kubectl describe pvc -n heimdall data-heimdall-postgresql-0
```

## Chart Development Workflow

### Iterative Development

```bash
# 1. Make template changes
vim heimdall/templates/heimdall-statefulset.yaml

# 2. Lint and validate
helm lint ./heimdall --strict
helm template heimdall ./heimdall | kubectl apply --dry-run=client -f -

# 3. Test installation
helm upgrade --install heimdall ./heimdall -n heimdall-dev

# 4. Verify deployment
kubectl get pods -n heimdall-dev
kubectl logs -n heimdall-dev heimdall-0 -f

# 5. Test upgrade path
helm upgrade heimdall ./heimdall -n heimdall-dev

# 6. Cleanup
helm uninstall heimdall -n heimdall-dev
```

### Schema Validation

```bash
# Validate values against schema
helm lint ./heimdall --strict  # Uses values.schema.json

# Test with invalid values (should fail)
helm install heimdall ./heimdall --dry-run \
  --set heimdall.replicaCount=invalid

# Skip schema validation (air-gapped environments)
helm install heimdall ./heimdall --skip-schema-validation
```

## Advanced Patterns

### Helm Diff Plugin

```bash
# Install helm-diff plugin
helm plugin install https://github.com/databus23/helm-diff

# Preview upgrade changes
helm diff upgrade heimdall ./heimdall -n heimdall

# Preview with custom values
helm diff upgrade heimdall ./heimdall -n heimdall -f new-values.yaml
```

### Helm Secrets Plugin

```bash
# Install helm-secrets plugin
helm plugin install https://github.com/jkroepke/helm-secrets

# Encrypt values file
helm secrets encrypt secrets.yaml

# Install with encrypted secrets
helm secrets install heimdall ./heimdall -n heimdall -f secrets.yaml.enc
```

### ArgoCD Integration

```bash
# Generate ArgoCD Application manifest
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: heimdall
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://mitre.github.io/heimdall-helm
    chart: heimdall
    targetRevision: 1.0.0
    helm:
      valueFiles:
        - values-production.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: heimdall
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF
```

## Quick Reference

### Most Common Commands

```bash
# Development workflow
helm lint ./heimdall --strict
helm template heimdall ./heimdall | kubectl apply --dry-run=client -f -
helm upgrade --install heimdall ./heimdall -n heimdall

# Debugging
kubectl get pods -n heimdall
kubectl logs -n heimdall heimdall-0 -f
kubectl describe pod -n heimdall heimdall-0
helm get values heimdall -n heimdall --all

# Cleanup
helm uninstall heimdall -n heimdall
kubectl delete namespace heimdall
```

## References

- [Helm Documentation](https://helm.sh/docs/)
- [Helm CLI Reference](https://helm.sh/docs/helm/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes kubectl Reference](https://kubernetes.io/docs/reference/kubectl/)
