# Testing Strategy

This document outlines testing strategies and procedures for the Heimdall Helm chart.

## Testing Levels

### 1. Syntax Validation (Pre-Commit)

**Purpose**: Catch syntax errors and basic issues before committing

```bash
# YAML syntax validation
helm lint ./heimdall

# Strict linting (fails on warnings)
helm lint ./heimdall --strict

# Template rendering test
helm template heimdall ./heimdall > /dev/null

# Kubernetes resource validation
helm template heimdall ./heimdall | kubectl apply --dry-run=client -f -
```

**Automated**: These should run automatically via git hooks or CI/CD

### 2. Schema Validation

**Purpose**: Validate values.yaml against values.schema.json

```bash
# Schema validation (automatic during lint with --strict)
helm lint ./heimdall --strict

# Test with invalid values (should fail)
helm install heimdall ./heimdall --dry-run \
  --set heimdall.replicaCount=invalid

# Test with missing required values (should fail)
helm install heimdall ./heimdall --dry-run \
  --set postgresql.enabled=false
# Should require externalDatabase.host

# Skip schema validation (for testing)
helm install heimdall ./heimdall --skip-schema-validation
```

**Expected Behavior**:
- ✅ Valid values: lint succeeds
- ❌ Invalid types: lint fails with schema error
- ❌ Missing required fields: lint fails with schema error

### 3. Template Unit Tests

**Purpose**: Test template logic and helper functions without requiring a Kubernetes cluster

```bash
# Install helm-unittest plugin
helm plugin install https://github.com/helm-unittest/helm-unittest

# Run all tests
helm unittest ./heimdall

# Run specific test file
helm unittest ./heimdall -f tests/statefulset_test.yaml

# Run tests with verbose output
helm unittest ./heimdall -v
```

**Current Test Suite: 92 tests across 11 test files (100% template coverage)**

```
Charts:      1 passed, 1 total
Test Suites: 11 passed, 11 total
Tests:       92 passed, 92 total
Time:        ~850ms
```

**Test Files:**

1. **statefulset_test.yaml** (12 tests)
   - Basic StatefulSet structure
   - Replicas configuration
   - envFrom pattern (ConfigMap + Secrets)
   - Secrets priority (existingSecret)
   - Container name/image
   - Health probes (startup + liveness)
   - DATABASE_PASSWORD injection
   - NODE_EXTRA_CA_CERTS (enabled/disabled)

2. **configmap_test.yaml** (10 tests)
   - ConfigMap creation
   - Embedded database config (HOST, PORT, NAME, USERNAME)
   - External database config
   - NODE_ENV (default + custom)
   - EXTERNAL_URL
   - Custom config variables

3. **secrets_test.yaml** (8 tests)
   - Existing secret (not created when specified)
   - Inline secrets from values
   - File-based secrets
   - Default behavior
   - Priority order (existingSecret > inline > file)
   - Metadata/labels
   - Secret type (Opaque)

4. **service_test.yaml** (7 tests)
   - Service creation
   - Service type (ClusterIP, LoadBalancer, NodePort)
   - Port configuration
   - Selector labels
   - Metadata labels

5. **ingress_test.yaml** (8 tests)
   - Disabled by default
   - Basic Ingress creation
   - IngressClassName
   - Annotations
   - TLS configuration
   - Multiple hosts
   - Backend service reference
   - Path/pathType configuration

6. **pdb_test.yaml** (8 tests)
   - PodDisruptionBudget disabled by default
   - Basic PDB creation
   - minAvailable (integer + percentage)
   - maxUnavailable (integer + percentage)
   - Selector labels
   - API version (policy/v1)

7. **hpa_test.yaml** (8 tests)
   - HorizontalPodAutoscaler disabled by default
   - Basic HPA creation
   - Min/max replicas
   - Scale target reference (StatefulSet)
   - CPU metrics
   - Memory metrics
   - Both CPU and memory metrics
   - API version (autoscaling/v2)

8. **serviceaccount_test.yaml** (5 tests)
   - ServiceAccount creation (enabled by default)
   - Custom name
   - Annotations (e.g., AWS IAM roles, GCP Workload Identity)
   - Labels

9. **cacerts_test.yaml** (5 tests)
   - CA certificates ConfigMap disabled by default
   - Not created when using existing configMapName
   - Basic ConfigMap creation with inline certificates
   - Multiple CA certificates
   - Labels

10. **gateway_test.yaml** (7 tests)
    - Istio Gateway/VirtualService disabled by default
    - Basic Gateway creation
    - Metadata
    - Annotations
    - Gateways configuration
    - Hosts configuration
    - HTTP routes

11. **helpers_test.yaml** (14 tests)
    - Database host helper (embedded vs external)
    - Database port helper (default + custom)
    - Database name helper (embedded vs external)
    - Database username helper (embedded vs external)
    - Bitnami PostgreSQL configuration overrides
    - Fullname helper
    - Labels helper
    - NODE_ENV from values

**Example Test** (`heimdall/tests/configmap_test.yaml`):

```yaml
suite: test heimdall configmap environment variables
templates:
  - configmap.yaml
tests:
  - it: should set DATABASE_HOST to embedded PostgreSQL service by default
    asserts:
      - equal:
          path: data.DATABASE_HOST
          value: RELEASE-NAME-heimdall-postgresql

  - it: should use external database host when postgresql.enabled=false
    set:
      postgresql.enabled: false
      externalDatabase.host: external-db.example.com
      externalDatabase.database: heimdall_prod
      externalDatabase.username: heimdall_user
    asserts:
      - equal:
          path: data.DATABASE_HOST
          value: external-db.example.com
      - equal:
          path: data.DATABASE_NAME
          value: heimdall_prod
```

**Bugs Discovered and Fixed by Unit Tests:**

1. **Duplicate DATABASE_* keys in ConfigMap** - ConfigMap template and env file both set DATABASE_NAME, DATABASE_USERNAME, DATABASE_PORT creating invalid YAML
2. **Wrong helper path** - `databaseHost` helper was checking `.Values.databaseHost` instead of `.Values.externalDatabase.host`
3. **Duplicate EXTERNAL_URL** - Being set in both template logic and override section

### 4. Integration Testing (Local Cluster)

**Purpose**: Test actual deployment to Kubernetes cluster

#### Setup Test Cluster

```bash
# Create kind cluster for testing
kind create cluster --name heimdall-test

# Or use existing cluster
kubectl config use-context kind-heimdall-dev
```

#### Basic Deployment Test

```bash
# Install chart
helm install heimdall-test ./heimdall -n heimdall-test --create-namespace

# Wait for pods ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=heimdall \
  -n heimdall-test --timeout=300s

# Check all pods running
kubectl get pods -n heimdall-test

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# heimdall-0                    1/1     Running   0          2m
# heimdall-postgresql-0         1/1     Running   0          2m

# Check services
kubectl get svc -n heimdall-test

# Test connectivity
kubectl run -n heimdall-test test-pod --rm -i --tty \
  --image=curlimages/curl -- curl -f http://heimdall-test:3000

# Cleanup
helm uninstall heimdall-test -n heimdall-test
kubectl delete namespace heimdall-test
```

#### Upgrade Path Testing

```bash
# Install current version
helm install heimdall-test ./heimdall -n heimdall-test --create-namespace

# Wait for ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=heimdall \
  -n heimdall-test --timeout=300s

# Make changes to chart
# ... edit templates ...

# Upgrade
helm upgrade heimdall-test ./heimdall -n heimdall-test

# Verify upgrade
kubectl rollout status statefulset/heimdall-test -n heimdall-test
helm history heimdall-test -n heimdall-test

# Cleanup
helm uninstall heimdall-test -n heimdall-test
kubectl delete namespace heimdall-test
```

#### Rollback Testing

```bash
# Install v1
helm install heimdall-test ./heimdall -n heimdall-test --create-namespace

# Upgrade to v2 (with changes)
helm upgrade heimdall-test ./heimdall -n heimdall-test --set heimdall.replicaCount=5

# Rollback to v1
helm rollback heimdall-test -n heimdall-test

# Verify rollback
helm history heimdall-test -n heimdall-test
kubectl get pods -n heimdall-test  # Should have original replica count

# Cleanup
helm uninstall heimdall-test -n heimdall-test
kubectl delete namespace heimdall-test
```

### 5. Configuration Testing

**Purpose**: Test different configuration scenarios

#### Test 1: Embedded PostgreSQL (Default)

```bash
helm install heimdall-test ./heimdall -n test-embedded --create-namespace

# Verify PostgreSQL pod created
kubectl get pods -n test-embedded | grep postgresql

# Verify database connection
kubectl logs -n test-embedded heimdall-0 | grep "DATABASE_HOST"
# Should show: heimdall-test-postgresql

kubectl delete namespace test-embedded
```

#### Test 2: External Database

```bash
# Install with external database
helm install heimdall-test ./heimdall -n test-external \
  --set postgresql.enabled=false \
  --set externalDatabase.host=postgres.example.com \
  --set externalDatabase.database=heimdall_external \
  --set externalDatabase.username=heimdall_user \
  --create-namespace

# Verify PostgreSQL pod NOT created
kubectl get pods -n test-external | grep postgresql
# Should return no results

# Verify external database config
kubectl get configmap -n test-external heimdall-test-config -o yaml | grep DATABASE_HOST
# Should show: postgres.example.com

kubectl delete namespace test-external
```

#### Test 3: Ingress Enabled

```bash
# Install with ingress
helm install heimdall-test ./heimdall -n test-ingress \
  --set heimdall.ingress.enabled=true \
  --set heimdall.ingress.hosts[0].host=heimdall.local \
  --create-namespace

# Verify ingress created
kubectl get ingress -n test-ingress

# Test ingress (requires ingress controller)
curl -H "Host: heimdall.local" http://localhost

kubectl delete namespace test-ingress
```

#### Test 4: High Availability Configuration

```bash
# Install HA configuration
helm install heimdall-test ./heimdall -n test-ha \
  --set heimdall.replicaCount=3 \
  --set heimdall.podDisruptionBudget.enabled=true \
  --set heimdall.podDisruptionBudget.minAvailable=2 \
  --create-namespace

# Verify 3 replicas
kubectl get pods -n test-ha
# Should show: heimdall-0, heimdall-1, heimdall-2

# Verify PDB created
kubectl get pdb -n test-ha

# Test pod disruption
kubectl drain <node-name> --ignore-daemonsets
# Should maintain at least 2 pods running

kubectl delete namespace test-ha
```

#### Test 5: Autoscaling

```bash
# Install with autoscaling
helm install heimdall-test ./heimdall -n test-hpa \
  --set heimdall.autoscaling.enabled=true \
  --set heimdall.autoscaling.minReplicas=2 \
  --set heimdall.autoscaling.maxReplicas=10 \
  --set heimdall.resources.requests.cpu=100m \
  --create-namespace

# Verify HPA created
kubectl get hpa -n test-hpa

# Verify replicas NOT set (HPA controls it)
kubectl get statefulset -n test-hpa heimdall-test -o yaml | grep replicas
# spec.replicas should not be set

# Generate load (requires metrics-server)
kubectl run -n test-hpa load-generator --rm -i --tty \
  --image=busybox -- /bin/sh -c "while true; do wget -q -O- http://heimdall-test:3000; done"

# Watch autoscaling
kubectl get hpa -n test-hpa --watch

kubectl delete namespace test-hpa
```

### 6. Secrets Management Testing

**Purpose**: Test three secrets approaches

#### Test 1: File-based Secrets (Default)

```bash
# Generate secrets file
./generate-heimdall-secrets.sh

# Verify secrets file exists
ls -la heimdall/env/heimdall-secrets.yaml

# Install
helm install heimdall-test ./heimdall -n test-secrets-file --create-namespace

# Verify secret created
kubectl get secret -n test-secrets-file heimdall-test-secrets

# Verify secret contains expected keys
kubectl get secret -n test-secrets-file heimdall-test-secrets -o jsonpath='{.data}' | jq keys

kubectl delete namespace test-secrets-file
```

#### Test 2: Existing Secret

```bash
# Create secret manually
kubectl create namespace test-secrets-existing
kubectl create secret generic heimdall-production-secrets -n test-secrets-existing \
  --from-literal=JWT_SECRET="$(openssl rand -hex 64)" \
  --from-literal=DATABASE_PASSWORD="$(openssl rand -hex 33)"

# Install with existing secret
helm install heimdall-test ./heimdall -n test-secrets-existing \
  --set heimdall.existingSecret=heimdall-production-secrets

# Verify chart did NOT create secret
kubectl get secret -n test-secrets-existing heimdall-test-secrets
# Should NOT exist

# Verify using existing secret
kubectl get statefulset -n test-secrets-existing heimdall-test -o yaml | grep secretName
# Should reference heimdall-production-secrets

kubectl delete namespace test-secrets-existing
```

#### Test 3: Inline Secrets

```bash
# Install with inline secrets
helm install heimdall-test ./heimdall -n test-secrets-inline \
  --set heimdall.secrets.JWT_SECRET="test-jwt-secret-$(openssl rand -hex 32)" \
  --set heimdall.secrets.DATABASE_PASSWORD="test-db-password-$(openssl rand -hex 16)" \
  --create-namespace

# Verify secret created with inline values
kubectl get secret -n test-secrets-inline heimdall-test-secrets -o jsonpath='{.data.JWT_SECRET}' | base64 -d
# Should show test-jwt-secret-...

kubectl delete namespace test-secrets-inline
```

### 7. Health Probe Testing

**Purpose**: Verify startup, liveness, and readiness probes

```bash
# Install chart
helm install heimdall-test ./heimdall -n test-probes --create-namespace

# Check probe configuration
kubectl get statefulset -n test-probes heimdall-test -o yaml | grep -A 10 "startupProbe"
kubectl get statefulset -n test-probes heimdall-test -o yaml | grep -A 10 "livenessProbe"
kubectl get statefulset -n test-probes heimdall-test -o yaml | grep -A 10 "readinessProbe"

# Watch pod startup
kubectl get pods -n test-probes -w

# Verify probes working
kubectl describe pod -n test-probes heimdall-0 | grep -A 5 "Liveness"
kubectl describe pod -n test-probes heimdall-0 | grep -A 5 "Readiness"

# Test probe endpoints manually
kubectl exec -n test-probes heimdall-0 -- curl -f http://localhost:3000/up
kubectl exec -n test-probes heimdall-0 -- curl -f http://localhost:3000/health_check/database

kubectl delete namespace test-probes
```

### 8. Database Migration Testing

**Purpose**: Test migration job execution

```bash
# Install chart
helm install heimdall-test ./heimdall -n test-migrations --create-namespace

# Check migration job
kubectl get jobs -n test-migrations

# Check job status
kubectl describe job -n test-migrations heimdall-test-migrate

# Check migration logs
kubectl logs -n test-migrations job/heimdall-test-migrate

# Verify migrations ran
kubectl exec -n test-migrations heimdall-postgresql-0 -- \
  psql -U postgres -d heimdall -c "SELECT * FROM \"SequelizeMeta\";"

# Test upgrade (migration should run again)
helm upgrade heimdall-test ./heimdall -n test-migrations

# Verify migration job recreated
kubectl get jobs -n test-migrations

kubectl delete namespace test-migrations
```

### 9. Helm Test Suite

**Purpose**: Automated tests using Helm test hooks

Create test templates in `heimdall/templates/tests/`:

#### Test 1: Connection Test

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "heimdall.fullname" . }}-test-connection
  labels:
    {{- include "heimdall.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  containers:
    - name: wget
      image: busybox
      command: ['wget']
      args: ['{{ include "heimdall.fullname" . }}:3000']
  restartPolicy: Never
```

#### Test 2: Database Connection Test

```yaml
# templates/tests/test-database.yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "heimdall.fullname" . }}-test-database
  labels:
    {{- include "heimdall.labels" . | nindent 4 }}
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": hook-succeeded
spec:
  containers:
    - name: postgres-check
      image: postgres:13
      command:
        - pg_isready
        - -h
        - {{ include "heimdall.databaseHost" . }}
        - -p
        - {{ include "heimdall.databasePort" . | quote }}
        - -U
        - {{ include "heimdall.databaseUsername" . }}
  restartPolicy: Never
```

#### Run Helm Tests

```bash
# Install chart
helm install heimdall-test ./heimdall -n test-suite --create-namespace

# Run tests
helm test heimdall-test -n test-suite

# Expected output:
# Pod heimdall-test-test-connection pending
# Pod heimdall-test-test-connection succeeded
# Pod heimdall-test-test-database pending
# Pod heimdall-test-test-database succeeded

# View test logs
helm test heimdall-test -n test-suite --logs

kubectl delete namespace test-suite
```

### 10. Performance Testing

**Purpose**: Test resource usage and performance

```bash
# Install with metrics
helm install heimdall-test ./heimdall -n test-perf \
  --set heimdall.resources.requests.cpu=100m \
  --set heimdall.resources.requests.memory=128Mi \
  --set heimdall.resources.limits.cpu=1000m \
  --set heimdall.resources.limits.memory=512Mi \
  --create-namespace

# Requires metrics-server installed
kubectl top pods -n test-perf
kubectl top nodes

# Load testing (basic)
kubectl run -n test-perf load-gen --rm -i --tty \
  --image=williamyeh/wrk -- \
  wrk -t4 -c100 -d30s http://heimdall-test:3000

# Monitor during load
kubectl top pods -n test-perf --watch

kubectl delete namespace test-perf
```

## Testing Checklist

### Pre-Commit Checklist

- [ ] `helm lint ./heimdall --strict` passes
- [ ] `helm template heimdall ./heimdall` renders without errors
- [ ] `kubectl apply --dry-run=client` validates successfully
- [ ] All template unit tests pass (`helm unittest ./heimdall`)
- [ ] values.schema.json validation passes

### Pre-PR Checklist

- [ ] Chart installs successfully to local cluster
- [ ] All pods reach Running state
- [ ] Health probes working (startup, liveness, readiness)
- [ ] Database migrations execute successfully
- [ ] Helm tests pass (`helm test`)
- [ ] Upgrade from previous version works
- [ ] Rollback works
- [ ] Both embedded and external database configs tested
- [ ] Secrets management tested (all three approaches)
- [ ] Documentation updated (CHANGELOG.md, README.md)

### Pre-Release Checklist

- [ ] All integration tests pass
- [ ] Upgrade path from previous major version tested
- [ ] Performance testing completed
- [ ] Security scanning passed (no critical vulnerabilities)
- [ ] Chart packaged successfully
- [ ] Chart published to repository
- [ ] Artifact Hub metadata correct
- [ ] CHANGELOG.md updated with release notes
- [ ] Git tag created with version number

## Continuous Integration (CI)

### GitHub Actions Workflow Example

```yaml
# .github/workflows/test-chart.yml
name: Test Helm Chart

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main, develop]

jobs:
  lint-test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v4
        with:
          version: v4.0.0

      - name: Lint chart
        run: helm lint ./heimdall --strict

      - name: Template validation
        run: helm template heimdall ./heimdall | kubectl apply --dry-run=client -f -

      - name: Unit tests
        run: |
          helm plugin install https://github.com/helm-unittest/helm-unittest
          helm unittest ./heimdall

  integration-test:
    runs-on: ubuntu-latest
    needs: lint-test
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up Helm
        uses: azure/setup-helm@v4

      - name: Create kind cluster
        uses: helm/kind-action@v1.9.0

      - name: Install chart
        run: |
          helm install heimdall ./heimdall -n heimdall --create-namespace --wait --timeout 5m

      - name: Run tests
        run: helm test heimdall -n heimdall --logs

      - name: Check pods
        run: kubectl get pods -n heimdall

      - name: Cleanup
        run: helm uninstall heimdall -n heimdall
```

## Troubleshooting Tests

### Test Failures

```bash
# Get detailed error
helm test heimdall-test -n test-suite --logs

# Check test pod status
kubectl get pods -n test-suite | grep test

# Describe failed test pod
kubectl describe pod -n test-suite heimdall-test-test-connection

# View test pod logs
kubectl logs -n test-suite heimdall-test-test-connection

# Manually run test command
kubectl run -n test-suite debug --rm -i --tty --image=busybox -- /bin/sh
# Inside pod: wget heimdall-test:3000
```

### Resource Issues

```bash
# Check if nodes have capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check PVC status
kubectl get pvc -n test-suite

# Check events for errors
kubectl get events -n test-suite --sort-by='.lastTimestamp'
```

## References

- [Helm Testing Documentation](https://helm.sh/docs/topics/chart_tests/)
- [helm-unittest Plugin](https://github.com/helm-unittest/helm-unittest)
- [Kubernetes Testing](https://kubernetes.io/docs/tasks/debug/debug-application/)
- [kind Documentation](https://kind.sigs.k8s.io/)
