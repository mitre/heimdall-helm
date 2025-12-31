# Helm Chart Testing: Comprehensive Research Overview

**Date**: 2025-12-31
**Research Focus**: Testing frameworks, methodologies, and best practices for Helm charts

---

## Executive Summary

Helm chart testing operates on multiple levels, from basic syntax validation to production-grade integration tests. The testing ecosystem provides:

1. **Built-in Helm Testing** - Native `helm test` with test hooks
2. **Unit Testing** - Template rendering validation (helm-unittest)
3. **Linting & Validation** - Schema validation, YAML syntax, Kubernetes manifest validation
4. **Integration Testing** - Real cluster deployment (chart-testing, Terratest, KUTTL)
5. **Policy Testing** - Security and compliance validation (Conftest/OPA, Polaris)

**Key Finding**: Production charts (Bitnami, Vulcan) layer multiple testing approaches:
- Linting + schema validation (CI gates)
- Template rendering tests (fast feedback)
- Integration tests in KIND/k3s (deployment validation)
- Multi-platform testing (GKE, AKS, EKS)
- Automated security scanning

---

## 1. Built-in Helm Testing (`helm test`)

### Overview

Helm's native testing framework uses **test hooks** to run validation pods after deployment.

**Official Documentation**:
- [Chart Tests](https://helm.sh/docs/topics/chart_tests/)
- [Chart Hooks](https://helm.sh/docs/topics/charts_hooks/)
- [helm test command](https://helm.sh/docs/helm/helm_test/)

### How It Works

Tests are Kubernetes Job definitions with the `helm.sh/hook: test` annotation:

```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: {{ include "heimdall.fullname" . }}-test-connection
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

**Run tests**:
```bash
helm install myapp ./chart
helm test myapp --logs
```

### Key Features

- **Hook Annotations**:
  - `helm.sh/hook: test` (required, replaces deprecated test-success/test-failure)
  - `helm.sh/hook-weight` - Control execution order
  - `helm.sh/hook-delete-policy` - Cleanup behavior (hook-succeeded, hook-failed, before-hook-creation)

- **Test Types**:
  - Connection tests (HTTP/TCP)
  - Database connectivity
  - Health endpoint validation
  - API smoke tests

### Limitations

- Requires actual deployment (can't test templates offline)
- Runs after installation (not pre-deployment validation)
- Limited to Kubernetes resource creation
- No template logic testing
- No assertions on rendered manifests

**Best For**: Production smoke tests, post-deployment validation

---

## 2. Unit Testing with helm-unittest

### Overview

**helm-unittest** is a BDD-style unit testing framework for Helm chart templates, installed as a Helm plugin.

**Resources**:
- [GitHub: helm-unittest/helm-unittest](https://github.com/helm-unittest/helm-unittest)
- [Artifact Hub: helm-unittest](https://artifacthub.io/packages/helm-plugin/unittest/unittest)
- [Big Bang Unit Tests Guide](https://docs-bigbang.dso.mil/latest/docs/community/development/helm-unittests/)

### Installation

```bash
helm plugin install https://github.com/helm-unittest/helm-unittest
```

### Key Features

- **Pure YAML Test Syntax** - No coding required
- **Offline Testing** - Renders templates locally (no cluster needed)
- **Fast Execution** - Instant feedback on template logic
- **Snapshot Testing** - Compare rendered manifests against baselines
- **BDD Style** - Readable test cases with descriptive assertions

### Example Test

```yaml
# tests/statefulset_test.yaml
suite: test heimdall statefulset
templates:
  - heimdall-statefulset.yaml
tests:
  - it: should use envFrom for ConfigMap and Secrets
    asserts:
      - contains:
          path: spec.template.spec.containers[0].envFrom
          content:
            configMapRef:
              name: RELEASE-NAME-heimdall-config
      - contains:
          path: spec.template.spec.containers[0].envFrom
          content:
            secretRef:
              name: RELEASE-NAME-heimdall-secrets

  - it: should set correct database host for embedded PostgreSQL
    set:
      postgresql.enabled: true
    asserts:
      - equal:
          path: spec.template.spec.containers[0].env[?(@.name=="DATABASE_HOST")].value
          value: RELEASE-NAME-postgresql

  - it: should set correct database host for external database
    set:
      postgresql.enabled: false
      externalDatabase.host: "postgres.example.com"
    asserts:
      - equal:
          path: spec.template.spec.containers[0].env[?(@.name=="DATABASE_HOST")].value
          value: postgres.example.com

  - it: should not set replicas when autoscaling enabled
    set:
      heimdall.autoscaling.enabled: true
    asserts:
      - isNull:
          path: spec.replicas
```

### Run Tests

```bash
# Run all tests
helm unittest ./heimdall

# Run with subchart tests
helm unittest ./heimdall --with-subchart

# Run specific test file
helm unittest ./heimdall -f tests/statefulset_test.yaml

# Generate JUnit XML for CI
helm unittest ./heimdall --output-type JUnit --output-file test-results.xml
```

### Benefits

- Catches template logic bugs before deployment
- Documents expected chart behavior
- Fast CI/CD feedback loop (no cluster required)
- Schema validation testing (values.schema.json)
- Multi-scenario configuration testing

**Best For**: Template logic validation, helper function testing, values processing

---

## 3. Integration Testing with chart-testing (ct)

### Overview

**chart-testing (ct)** is the official Helm tool for linting and testing charts in CI/CD pipelines.

**Resources**:
- [GitHub: helm/chart-testing](https://github.com/helm/chart-testing)
- [Official Blog: Chart Testing Intro](https://helm.sh/blog/chart-testing-intro/)
- [Red Hat: Linting and Testing Helm Charts](https://redhat-cop.github.io/ci/linting-testing-helm-charts.html)

### Installation

```bash
# Install via Homebrew
brew install chart-testing

# Or use Docker image (recommended for CI)
docker pull quay.io/helmpack/chart-testing:latest
```

### Key Features

- **Git-aware Change Detection** - Only tests modified charts (monorepo support)
- **Automated Linting** - YAML lint, Chart.yaml validation, helm lint
- **Installation Testing** - Deploys to real cluster and validates
- **Upgrade Testing** - Tests helm upgrade path (backward compatibility)
- **Multi-version Testing** - Tests against multiple Kubernetes versions

### Commands

```bash
# Lint only
ct lint --config ct.yaml

# Install test (requires cluster)
ct install --config ct.yaml

# Lint + install
ct lint-and-install --config ct.yaml

# List changed charts
ct list-changed --config ct.yaml
```

### Configuration Example

```yaml
# ct.yaml
helm-extra-args: --timeout 600s
chart-dirs:
  - .
chart-repos:
  - bitnami=https://charts.bitnami.com/bitnami
validate-maintainers: false
check-version-increment: true
```

### Upgrade Testing

```bash
# Test upgrade path from previous version
ct install --upgrade --config ct.yaml
```

This installs the chart from the target branch (e.g., `main`), then upgrades to the PR branch version.

### CI/CD Integration

```yaml
# .github/workflows/test.yml
- name: Run chart-testing (lint)
  run: ct lint --config ct.yaml

- name: Create kind cluster
  uses: helm/kind-action@v1.10.0

- name: Run chart-testing (install)
  run: ct install --config ct.yaml
```

**Best For**: CI/CD pipelines, monorepo testing, regression prevention

---

## 4. End-to-End Testing with Terratest

### Overview

**Terratest** is a Go library for writing automated tests for infrastructure code, including Helm charts.

**Resources**:
- [Gruntwork: Terratest for Kubernetes and Helm](https://www.gruntwork.io/blog/automated-testing-for-kubernetes-and-helm-charts-using-terratest)
- [GitHub: gruntwork-io/terratest](https://github.com/gruntwork-io/terratest)
- [Example: terratest-helm-testing-example](https://github.com/gruntwork-io/terratest-helm-testing-example)

### Two Testing Approaches

#### 1. Template Tests (Unit-style)

Render templates with `helm template` and validate output:

```go
// template_test.go
func TestHelmChartTemplateRendering(t *testing.T) {
    helmChartPath := "../heimdall"

    options := &helm.Options{
        SetValues: map[string]string{
            "heimdall.replicaCount": "3",
            "postgresql.enabled":    "true",
        },
    }

    // Render the template
    output := helm.RenderTemplate(t, options, helmChartPath, "release-name", []string{"templates/heimdall-statefulset.yaml"})

    // Parse output
    var statefulSet appsv1.StatefulSet
    helm.UnmarshalK8SYaml(t, output, &statefulSet)

    // Assertions
    assert.Equal(t, int32(3), *statefulSet.Spec.Replicas)
}
```

#### 2. Integration Tests (Deployment)

Deploy to real cluster and validate behavior:

```go
// integration_test.go
func TestHelmChartDeployment(t *testing.T) {
    t.Parallel()

    helmChartPath := "../heimdall"
    kubectlOptions := k8s.NewKubectlOptions("", "", "heimdall-test")

    options := &helm.Options{
        KubectlOptions: kubectlOptions,
        SetValues: map[string]string{
            "postgresql.enabled": "true",
        },
    }

    defer helm.Delete(t, options, "heimdall-test", true)

    // Install chart
    helm.Install(t, options, helmChartPath, "heimdall-test")

    // Wait for pods
    k8s.WaitUntilPodAvailable(t, kubectlOptions, "heimdall-0", 60, 10*time.Second)

    // Test connectivity
    tunnel := k8s.NewTunnel(kubectlOptions, k8s.ResourceTypePod, "heimdall-0", 3000, 3000)
    defer tunnel.Close()
    tunnel.ForwardPort(t)

    http_helper.HttpGetWithRetry(t, "http://localhost:3000/up", nil, 200, "OK", 30, 3*time.Second)
}
```

### Key Features

- **Real Cluster Testing** - Deploy to EKS, GKE, AKS, KIND, minikube
- **Full Go Testing Framework** - Complex assertions, retry logic, timeouts
- **Multi-service Testing** - Test chart interactions with other services
- **Cleanup Handling** - Automatic teardown with defer
- **Parallel Execution** - Run tests concurrently

### Benefits

- Production-like testing environment
- Complex scenario validation
- API/endpoint testing
- Database migration validation
- Multi-chart dependency testing

**Best For**: Integration tests, E2E validation, complex deployment scenarios

---

## 5. Declarative Testing with KUTTL

### Overview

**KUTTL** (KUbernetes Test TooL) provides declarative testing for Kubernetes resources, including Helm charts.

**Resources**:
- [KUTTL Documentation](https://kuttl.dev/)
- [KUTTL Test Harness](https://kuttl.dev/docs/kuttl-test-harness.html)
- [GitHub: kudobuilder/kuttl](https://github.com/kudobuilder/kuttl)

### Key Features

- **Declarative YAML Tests** - No code required
- **Test Steps** - Sequential validation steps
- **State Assertions** - Wait for desired state
- **Helm Support** - Install charts via TestSuite commands

### Test Structure

```yaml
# kuttl-test.yaml
apiVersion: kuttl.dev/v1beta1
kind: TestSuite
metadata:
  name: heimdall-test
commands:
  - command: helm install heimdall ./heimdall -n ${NAMESPACE}
testDirs:
  - tests/e2e
startKIND: true
kindNodeCache: true
```

```yaml
# tests/e2e/basic-deployment/00-install.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: heimdall
spec:
  replicas: 1
```

```yaml
# tests/e2e/basic-deployment/00-assert.yaml
apiVersion: v1
kind: Pod
metadata:
  name: heimdall-0
status:
  phase: Running
  conditions:
    - type: Ready
      status: "True"
```

### Running Tests

```bash
# Run all tests
kubectl kuttl test

# Run specific test
kubectl kuttl test --test basic-deployment

# Run against existing cluster
kubectl kuttl test --start-kind=false
```

**Best For**: Declarative E2E tests, operator testing, multi-step scenarios

---

## 6. Policy Testing with Conftest and OPA

### Overview

**Conftest** uses Open Policy Agent (OPA) to validate Helm charts against security and compliance policies.

**Resources**:
- [Conftest Official Site](https://www.conftest.dev/)
- [GitHub: instrumenta/helm-conftest](https://github.com/instrumenta/helm-conftest)
- [Nearform: OPA Policy Testing](https://nearform.com/digital-community/opa-policy-based-testing-of-helm-charts/)
- [GitHub: nearform/helm-OPA-policy-testing-templates](https://github.com/nearform/helm-OPA-policy-testing-templates)

### How It Works

1. Render Helm templates to Kubernetes manifests
2. Apply Rego policies (OPA language) to manifests
3. Report violations before deployment

### Installation

```bash
# Helm plugin
helm plugin install https://github.com/instrumenta/helm-conftest

# Standalone
brew install conftest
```

### Example Policy

```rego
# policy/security.rego
package main

deny[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.securityContext.runAsNonRoot
    msg = "Container must run as non-root user"
}

deny[msg] {
    input.kind == "StatefulSet"
    container := input.spec.template.spec.containers[_]
    not container.securityContext.readOnlyRootFilesystem
    msg = sprintf("Container '%s' must have read-only root filesystem", [container.name])
}

warn[msg] {
    input.kind == "Service"
    input.spec.type == "LoadBalancer"
    msg = "Consider using Ingress instead of LoadBalancer"
}
```

### Testing Charts

```bash
# Test rendered templates
helm template heimdall ./heimdall | conftest test -

# Test with custom policies
conftest test -p policy/ <(helm template heimdall ./heimdall)

# Use as Helm plugin
helm conftest heimdall ./heimdall
```

### Policy Categories

- **Security**: Non-root users, privileged containers, capabilities
- **Best Practices**: Resource limits, labels, probes
- **Compliance**: PCI-DSS, HIPAA, CIS Benchmarks
- **Organization Standards**: Naming conventions, required annotations

**Best For**: Security validation, compliance enforcement, governance

---

## 7. Configuration Validation with Polaris

### Overview

**Polaris** by Fairwinds validates Kubernetes resources against best practices for security, efficiency, and reliability.

**Resources**:
- [GitHub: FairwindsOps/polaris](https://github.com/FairwindsOps/polaris)
- [Polaris Documentation](https://polaris.docs.fairwinds.com/)
- [Artifact Hub: polaris](https://artifacthub.io/packages/helm/fairwinds-stable/polaris)

### Key Features

- **30+ Built-in Checks** - Security, reliability, efficiency
- **Custom Checks** - JSON Schema validation
- **Multiple Modes** - Dashboard, admission controller, audit, infrastructure-as-code

### Audit Helm Charts

```bash
# Install Polaris CLI
brew install fairwinds/tap/polaris

# Audit Helm chart
polaris audit --helm-chart ./heimdall --helm-values ./heimdall/values.yaml

# Output JSON
polaris audit --helm-chart ./heimdall --format json > polaris-results.json

# Set score threshold (fail CI if below threshold)
polaris audit --helm-chart ./heimdall --set-exit-code-below-score 90
```

### Common Checks

- **Images**: Must have version tags (not `latest`)
- **Probes**: Liveness and readiness probes required
- **Resources**: CPU/memory requests and limits
- **Security**: Non-root user, read-only filesystem
- **Networking**: NetworkPolicy recommended

### CI/CD Integration

```yaml
# .github/workflows/polaris.yml
- name: Run Polaris audit
  run: |
    helm repo add fairwinds-stable https://charts.fairwinds.com/stable
    helm install polaris fairwinds-stable/polaris --namespace polaris --create-namespace
    polaris audit --helm-chart ./heimdall --set-exit-code-below-score 80
```

**Best For**: Best practices enforcement, security auditing, pre-deployment validation

---

## 8. The Testing Pyramid for Helm Charts

### Test Levels (Fast → Slow, Cheap → Expensive)

```
        /\
       /  \
      / E2E\          10% - Full deployment tests (Terratest, KUTTL)
     /______\
    /        \
   /Integration\     30% - Real cluster tests (ct install, helm test)
  /____________\
 /              \
/  Unit Tests    \   60% - Template tests (helm-unittest, helm template)
/________________\
       Base         100% - Linting & validation (helm lint, schema, conftest)
```

### Layer Breakdown

#### Base: Linting & Validation (100% coverage)
- **Tools**: `helm lint`, `values.schema.json`, `conftest`, `polaris`
- **Speed**: < 5 seconds
- **Purpose**: Catch syntax errors, schema violations, policy issues
- **CI Gate**: Must pass before PR approval

#### Level 1: Unit Tests (60% of test effort)
- **Tools**: `helm-unittest`, `helm template` + assertions
- **Speed**: 5-30 seconds
- **Purpose**: Validate template logic, helper functions, conditional rendering
- **Examples**:
  - Database host selection (embedded vs external)
  - Replica count with/without autoscaling
  - envFrom vs individual env vars
  - Secret priority (existingSecret > inline > file)

#### Level 2: Integration Tests (30% of test effort)
- **Tools**: `ct install`, `helm test`, Terratest (basic)
- **Speed**: 2-5 minutes
- **Purpose**: Verify deployment to cluster, pod startup, basic connectivity
- **Examples**:
  - Chart installs successfully
  - Pods reach Running state
  - Health probes pass
  - Service endpoints accessible
  - Database migrations complete

#### Level 3: E2E Tests (10% of test effort)
- **Tools**: Terratest (full), KUTTL, manual QA
- **Speed**: 10-30 minutes
- **Purpose**: Validate production-like scenarios, upgrade paths, multi-scenario testing
- **Examples**:
  - Upgrade from previous version
  - HA failover scenarios
  - External database integration
  - OAuth provider authentication
  - Multi-zone deployment

---

## 9. Production Testing: Bitnami's Approach

### Overview

Bitnami charts undergo rigorous multi-platform testing before release.

**Resources**:
- [Bitnami Charts Testing Guide](https://github.com/bitnami/charts/blob/main/TESTING.md)
- [Bitnami Release Process](https://docs.bitnami.com/kubernetes/faq/get-started/understand-charts-release-process/)

### Testing Phases

#### 1. Pull Request Validation (Pre-Merge)
- Helm lint (strict mode)
- Template rendering validation
- Unit tests (helm-unittest)
- Schema validation
- ct install to KIND cluster

#### 2. Multi-Platform Testing (Pre-Release)
Deployed to multiple Kubernetes platforms:
- **Cloud**: GKE, AKS, EKS
- **On-Premise**: TKG (Tanzu Kubernetes Grid)
- **Versions**: Multiple K8s server versions (1.28, 1.29, 1.30)
- **Helm Versions**: Helm 3.x and 4.x

#### 3. Test Types

**Verification Tests**:
- File existence and permissions
- Configuration applied correctly
- Resource creation (PVCs, ConfigMaps, Secrets)
- Labels and annotations

**Functional Tests**:
- User-facing functionality (login/logout)
- API operations (CRUD)
- Headless browser automation (Selenium)
- Integration with external services (SMTP, LDAP)

#### 4. Upgrade Testing
- **Chart Upgrade**: Previous version → new version
- **Backward Compatibility**: Non-major changes must upgrade cleanly
- **Rollback Testing**: Verify rollback to previous version works

#### 5. Security Scanning
- CVE scanning (Trivy, Grype)
- Best practices validation (Polaris)
- Secret exposure checks
- Image vulnerability scanning

### Timeline
- **PR Tests**: 5-15 minutes
- **Full Release Pipeline**: 2-24 hours (multi-cluster, multi-scenario)

### Key Takeaways
- Layer multiple testing approaches
- Test upgrade paths, not just fresh installs
- Validate on target platforms (cloud providers)
- Automate functional tests (not just deployment tests)

---

## 10. Best Practices for Helm Chart Testing

### 1. Start with Schema Validation

**Always use `values.schema.json`**:
```json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["heimdall"],
  "properties": {
    "heimdall": {
      "type": "object",
      "properties": {
        "replicaCount": {
          "type": "integer",
          "minimum": 1,
          "maximum": 100
        }
      }
    }
  }
}
```

**Benefits**:
- Catch invalid values before rendering
- Document expected types and ranges
- Fail fast in CI/CD

### 2. Layer Your Tests (Pyramid)

**Fast feedback loop**:
```bash
# Pre-commit (< 10 seconds)
helm lint ./heimdall --strict
helm template heimdall ./heimdall > /dev/null

# Pre-push (< 60 seconds)
helm unittest ./heimdall
conftest test <(helm template heimdall ./heimdall)

# PR validation (< 5 minutes)
ct lint-and-install --config ct.yaml

# Pre-release (< 30 minutes)
terratest integration tests
```

### 3. Test Common Scenarios

**Minimum test coverage**:
- ✅ Default values (embedded database)
- ✅ External database
- ✅ Ingress enabled
- ✅ Autoscaling enabled
- ✅ High availability (multi-replica)
- ✅ NetworkPolicy enabled
- ✅ Custom secrets (existingSecret)

### 4. Validate Upgrade Paths

**Don't just test fresh installs**:
```bash
# Install v1.0.0
helm install heimdall ./heimdall --version 1.0.0

# Upgrade to v1.1.0
helm upgrade heimdall ./heimdall --version 1.1.0

# Verify no downtime, data preserved
```

### 5. Use CI/CD Gates

**Example GitHub Actions**:
```yaml
# Required checks (fast, always run)
- helm lint --strict
- helm template validation
- helm unittest
- schema validation

# Optional checks (slower, run on schedule)
- ct install (KIND cluster)
- Terratest integration
- Multi-platform deployment
```

### 6. Document Expected Behavior

**Test as documentation**:
```yaml
# tests/database_test.yaml
suite: database configuration
tests:
  - it: should use embedded PostgreSQL by default
    asserts:
      - equal:
          path: spec.template.spec.containers[0].env[?(@.name=="DATABASE_HOST")].value
          value: RELEASE-NAME-postgresql

  - it: should support external database when postgresql.enabled=false
    set:
      postgresql.enabled: false
      externalDatabase.host: postgres.prod.example.com
    asserts:
      - equal:
          path: spec.template.spec.containers[0].env[?(@.name=="DATABASE_HOST")].value
          value: postgres.prod.example.com
```

### 7. Fail Fast, Fail Clearly

**Helpful error messages**:
```yaml
# values.schema.json
{
  "if": {
    "properties": {
      "postgresql": {
        "properties": {
          "enabled": {"const": false}
        }
      }
    }
  },
  "then": {
    "required": ["externalDatabase"],
    "properties": {
      "externalDatabase": {
        "required": ["host", "database"],
        "errorMessage": "When postgresql.enabled=false, you must configure externalDatabase.host and externalDatabase.database"
      }
    }
  }
}
```

### 8. Test Security Configurations

**Validate security defaults**:
```bash
# Check non-root user
helm template heimdall ./heimdall | \
  yq '.spec.template.spec.securityContext.runAsNonRoot == true'

# Check read-only filesystem
conftest test -p security-policies/ <(helm template heimdall ./heimdall)
```

---

## 11. CI/CD Integration Patterns

### Minimal CI Pipeline

```yaml
# .github/workflows/helm-test.yml
name: Helm Chart CI

on:
  pull_request:
    branches: [main, develop]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v4

      - name: Lint chart
        run: helm lint ./heimdall --strict

      - name: Validate templates
        run: helm template heimdall ./heimdall | kubectl apply --dry-run=client -f -

  unit-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v4

      - name: Install helm-unittest
        run: helm plugin install https://github.com/helm-unittest/helm-unittest

      - name: Run unit tests
        run: helm unittest ./heimdall

  integration-test:
    runs-on: ubuntu-latest
    needs: [lint, unit-test]
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v4
      - uses: helm/kind-action@v1.10.0

      - name: Install chart
        run: |
          ./generate-heimdall-secrets.sh
          helm install heimdall ./heimdall -n heimdall --create-namespace --wait

      - name: Run helm tests
        run: helm test heimdall -n heimdall --logs
```

### Advanced CI Pipeline (Bitnami-style)

```yaml
# .github/workflows/helm-test-advanced.yml
name: Advanced Helm Testing

on:
  pull_request:
    branches: [main]

jobs:
  lint-validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Lint
        run: ct lint --config ct.yaml

      - name: Policy validation
        run: |
          helm template heimdall ./heimdall | conftest test -

      - name: Security scan
        run: |
          polaris audit --helm-chart ./heimdall --set-exit-code-below-score 80

  test-scenarios:
    runs-on: ubuntu-latest
    needs: lint-validate
    strategy:
      matrix:
        scenario:
          - embedded-postgres
          - external-postgres
          - ingress-enabled
          - ha-config
    steps:
      - uses: actions/checkout@v4
      - uses: azure/setup-helm@v4
      - uses: helm/kind-action@v1.10.0

      - name: Test scenario
        run: |
          ./test-scenarios/${{ matrix.scenario }}.sh

  upgrade-test:
    runs-on: ubuntu-latest
    needs: lint-validate
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Test upgrade path
        run: ct install --upgrade --config ct.yaml
```

---

## 12. Tool Comparison Matrix

| Tool | Type | Speed | Cluster Required | Language | Best For |
|------|------|-------|------------------|----------|----------|
| `helm lint` | Linting | ⚡⚡⚡ (< 5s) | No | N/A | Syntax validation |
| `helm template` | Rendering | ⚡⚡⚡ (< 5s) | No | N/A | Template preview |
| `helm-unittest` | Unit | ⚡⚡ (10-30s) | No | YAML | Template logic |
| `conftest` | Policy | ⚡⚡ (10-30s) | No | Rego | Security/compliance |
| `polaris` | Audit | ⚡⚡ (10-30s) | No | N/A | Best practices |
| `ct` (chart-testing) | Integration | ⚡ (2-5m) | Yes | N/A | CI/CD pipelines |
| `helm test` | Smoke | ⚡ (1-3m) | Yes | N/A | Post-deploy validation |
| Terratest | E2E | 🐌 (10-30m) | Yes | Go | Complex scenarios |
| KUTTL | E2E | 🐌 (10-30m) | Yes | YAML | Declarative E2E |

---

## 13. Recommended Testing Stack for Heimdall

### Phase 1: Foundation (Immediate)
✅ **Already implemented** (`docs/TESTING.md`)

1. **Linting** - `helm lint --strict`
2. **Schema Validation** - `values.schema.json`
3. **Template Rendering** - `helm template` validation
4. **Basic Helm Tests** - `templates/tests/test-connection.yaml`

### Phase 2: Unit Testing (Next)
**Add to chart**:

1. **Install helm-unittest**:
   ```bash
   helm plugin install https://github.com/helm-unittest/helm-unittest
   ```

2. **Create test suite** (`heimdall/tests/`):
   - `statefulset_test.yaml` - envFrom, replicas, database config
   - `configmap_test.yaml` - Environment variables
   - `secrets_test.yaml` - Three secrets approaches
   - `helpers_test.yaml` - Template helper functions
   - `service_test.yaml` - Service configuration
   - `ingress_test.yaml` - Ingress routing

3. **CI Integration**:
   ```yaml
   - name: Unit tests
     run: helm unittest ./heimdall
   ```

### Phase 3: Integration Testing (Future)
**Expand CI pipeline**:

1. **chart-testing (ct)**:
   ```yaml
   # ct.yaml
   chart-dirs:
     - .
   chart-repos:
     - bitnami=https://charts.bitnami.com/bitnami
   ```

2. **Multi-scenario tests**:
   - Embedded PostgreSQL
   - External PostgreSQL
   - Ingress + TLS
   - HA configuration (3 replicas, PDB)
   - Autoscaling (HPA)

3. **Upgrade path tests**:
   ```bash
   ct install --upgrade
   ```

### Phase 4: Policy & Security (Ongoing)
**Add governance**:

1. **Conftest policies** (`policy/`):
   - Security: Non-root, read-only FS, no privileged
   - Best practices: Resource limits, probes
   - Organization: Required labels, annotations

2. **Polaris audits**:
   ```bash
   polaris audit --helm-chart ./heimdall --set-exit-code-below-score 80
   ```

### Phase 5: E2E Testing (Optional)
**For complex scenarios**:

1. **Terratest** (Go-based):
   - OAuth provider integration
   - Database migration validation
   - Multi-replica deployment
   - Upgrade scenarios

2. **KUTTL** (declarative):
   - GitLab authentication flow
   - Multi-user scenarios
   - LDAP integration

---

## 14. Quick Reference: Common Commands

### Linting & Validation
```bash
# Basic lint
helm lint ./heimdall

# Strict lint (fail on warnings)
helm lint ./heimdall --strict

# Template rendering
helm template heimdall ./heimdall

# Kubernetes validation
helm template heimdall ./heimdall | kubectl apply --dry-run=client -f -

# Schema validation
helm install heimdall ./heimdall --dry-run --debug
```

### Unit Testing
```bash
# Install plugin
helm plugin install https://github.com/helm-unittest/helm-unittest

# Run all tests
helm unittest ./heimdall

# Specific test file
helm unittest ./heimdall -f tests/statefulset_test.yaml

# With coverage
helm unittest ./heimdall --with-subchart -o coverage.xml
```

### Integration Testing
```bash
# chart-testing
ct lint --config ct.yaml
ct install --config ct.yaml
ct lint-and-install --config ct.yaml

# helm test (post-deployment)
helm test heimdall -n heimdall --logs
```

### Policy Testing
```bash
# Conftest
helm template heimdall ./heimdall | conftest test -

# Polaris
polaris audit --helm-chart ./heimdall --format json
```

---

## 15. Key Takeaways

1. **Layer your testing** - Pyramid approach (fast → slow, many → few)
2. **Schema validation is mandatory** - Catch errors before rendering
3. **Unit tests document behavior** - Tests as living documentation
4. **Test upgrade paths** - Not just fresh installs
5. **Automate in CI/CD** - Fast feedback, prevent regressions
6. **Production charts use multiple tools** - Bitnami: lint + unittest + ct + functional tests
7. **Security is non-negotiable** - Conftest/Polaris should gate deployments
8. **Start simple, expand gradually** - Begin with lint/unittest, add integration later

---

## Sources

### Official Helm Documentation
- [Chart Tests](https://helm.sh/docs/topics/chart_tests/)
- [Chart Hooks](https://helm.sh/docs/topics/charts_hooks/)
- [helm test command](https://helm.sh/docs/helm/helm_test/)

### Testing Frameworks
- [helm-unittest GitHub](https://github.com/helm-unittest/helm-unittest)
- [chart-testing (ct) GitHub](https://github.com/helm/chart-testing)
- [Terratest for Kubernetes and Helm](https://www.gruntwork.io/blog/automated-testing-for-kubernetes-and-helm-charts-using-terratest)
- [Terratest GitHub](https://github.com/gruntwork-io/terratest)
- [KUTTL Documentation](https://kuttl.dev/)
- [KUTTL GitHub](https://github.com/kudobuilder/kuttl)

### Policy & Security
- [Conftest Official Site](https://www.conftest.dev/)
- [helm-conftest GitHub](https://github.com/instrumenta/helm-conftest)
- [Nearform: OPA Policy Testing](https://nearform.com/digital-community/opa-policy-based-testing-of-helm-charts/)
- [Polaris GitHub](https://github.com/FairwindsOps/polaris)
- [Polaris Documentation](https://polaris.docs.fairwinds.com/)

### Best Practices & Guides
- [Bitnami Charts Testing](https://github.com/bitnami/charts/blob/main/TESTING.md)
- [Red Hat: Linting and Testing Helm Charts](https://redhat-cop.github.io/ci/linting-testing-helm-charts.html)
- [DEV: Ensuring Effective Helm Charts](https://dev.to/hkhelil/ensuring-effective-helm-charts-with-linting-testing-and-diff-checks-ni0)
- [Medium: Advanced Test Practices for Helm Charts](https://medium.com/@zelldon91/advanced-test-practices-for-helm-charts-587caeeb4cb)
- [Baeldung: How to Validate Helm Chart Content](https://www.baeldung.com/ops/helm-validate-chart-content)

### Community Resources
- [YR's Blog: Testing Helm Charts Part I](https://grem1.in/post/helm-testing-pt1/)
- [YR's Blog: Testing Helm Charts Part II](https://grem1.in/post/helm-testing-pt2/)
- [Big Bang Unit Tests Guide](https://docs-bigbang.dso.mil/latest/docs/community/development/helm-unittests/)
