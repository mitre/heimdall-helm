# Heimdall Helm Chart Modernization Plan

This document outlines the strategy for modernizing the Heimdall Helm chart based on the patterns and best practices established in the Vulcan Helm chart.

## Repository Naming

**Current**: `heimdall2-helm`
**Proposed**: `heimdall-helm`

**Rationale**: Remove version dependency from repository name for consistency with `vulcan-helm`. The chart version and app version should handle versioning, not the repository name.

## Current Issues to Address

Based on [open issues](https://github.com/mitre/heimdall2-helm/issues?q=sort%3Aupdated-desc+is%3Aissue+is%3Aopen):

### High Priority Issues

1. **Issue #33: CA Certificate Filename Hardcoded**
   - **Problem**: `SSL_CERT_FILE` and `NODE_EXTRA_CA_CERTS` hardcoded to `certs.pem`
   - **Solution**: Dynamically determine filename from values.yaml or standardize filename in ConfigMap
   - **Vulcan Pattern**: See `ca-certificates-configmap.yaml` - allows multiple certs with dynamic filenames

2. **Issue #13: PV Reconnection**
   - **Problem**: Creates new PVC/PV on every deployment instead of reconnecting to existing
   - **Solution**: Use StatefulSet with volumeClaimTemplates (like PostgreSQL pattern)
   - **Vulcan Pattern**: Bitnami PostgreSQL subchart uses StatefulSet properly

3. **Issue #24: Database Password in stringData**
   - **Problem**: Inconsistent secret handling (some use `data`, some use `stringData`)
   - **Solution**: Standardize on `stringData` for all text secrets (automatically base64 encoded by Kubernetes)
   - **Vulcan Pattern**: All secrets use consistent approach

### Medium Priority Issues

4. **Issue #22: Validation Utility**
   - **Problem**: No pre-deployment validation of chart configuration
   - **Solution**: Implement `values.schema.json` for JSON Schema validation
   - **Additional**: Consider checkov policies for custom validation
   - **Vulcan Pattern**: `values.schema.json` validates types, enums, required fields

5. **Issue #29: Init Container UBI 9**
   - **Problem**: Init container uses outdated base image
   - **Solution**: Update to UBI 9 or Alpine (lighter weight)
   - **Vulcan Pattern**: Uses `postgres:13-alpine` for init container

6. **Issue #8: Documentation Update**
   - **Problem**: Outdated or missing documentation
   - **Solution**: Create comprehensive CLAUDE.md (like Vulcan)
   - **Include**: Cluster setup, ingress configuration, OIDC/OAuth setup

### Low Priority Issues

7. **Issue #9: Add Tests**
   - **Solution**: Implement Helm test hooks in `templates/tests/`
   - **Vulcan Pattern**: `templates/tests/test-connection.yaml`

8. **Issue #6: Duplicate Host Configuration**
   - **Problem**: Ingress host value potentially duplicated
   - **Solution**: Review ingress template, use single source of truth
   - **Vulcan Pattern**: Single `ingress.hosts` array in values.yaml

## Migration Strategy (Applying Vulcan Patterns)

### 1. Chart Structure Modernization

**Adopt from Vulcan chart**:

```
heimdall/
├── Chart.yaml                  # Update with proper annotations
├── Chart.lock                  # Lock dependencies
├── values.yaml                 # Restructure following Vulcan pattern
├── values.schema.json          # **NEW** - JSON Schema validation
├── README.md                   # Auto-generated
├── README.md.gotmpl            # **NEW** - Template for generation
├── CHANGELOG.md                # **NEW** - Track changes
├── charts/                     # Dependencies
│   └── postgresql-16.x.x.tgz   # Bitnami PostgreSQL subchart
├── env/                        # **NEW** - Configuration files
│   ├── heimdall-config.yaml    # Non-sensitive environment variables
│   └── heimdall-secrets.yaml   # Sensitive data (gitignored)
└── templates/
    ├── _helpers.tpl            # **ENHANCE** - Add database helpers
    ├── NOTES.txt               # **ENHANCE** - Better post-install instructions
    ├── configmap.yaml          # Environment variables
    ├── heimdall-secrets.yaml   # **ENHANCE** - Support 3 approaches
    ├── heimdall-deployment.yaml  # Or StatefulSet if PV needed
    ├── heimdall-service.yaml
    ├── heimdall-serviceaccount.yaml
    ├── db-migrate-job.yaml     # **NEW** - Sequelize migrations via Helm hook
    ├── ingress.yaml            # **ENHANCE** - Fix OAuth callback URLs
    ├── hpa.yaml                # **NEW** - Autoscaling support
    ├── poddisruptionbudget.yaml  # **NEW** - HA by default
    ├── networkpolicy.yaml      # **NEW** - Optional network isolation
    ├── servicemonitor.yaml     # **NEW** - Prometheus integration
    ├── ca-certificates-configmap.yaml  # **FIX** - Dynamic filenames
    └── tests/
        └── test-connection.yaml  # **NEW** - Helm tests
```

### 2. Database Migration (Critical)

**Current**: Likely standalone PostgreSQL or embedded
**Target**: Bitnami PostgreSQL subchart (like Vulcan)

**Chart.yaml dependencies**:
```yaml
dependencies:
  - name: postgresql
    version: "~16.0.0"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
```

**Template helpers** (`_helpers.tpl`):
```yaml
{{/*
Get the database host
*/}}
{{- define "heimdall.databaseHost" -}}
{{- if .Values.postgresql.enabled }}
{{- include "heimdall.postgresql.fullname" . }}
{{- else }}
{{- .Values.externalDatabase.host }}
{{- end }}
{{- end }}

{{/*
Construct DATABASE_URL for Sequelize
*/}}
{{- define "heimdall.databaseURL" -}}
{{- printf "postgresql://%s:$(DATABASE_PASSWORD)@%s:%s/%s"
    (include "heimdall.databaseUsername" .)
    (include "heimdall.databaseHost" .)
    (include "heimdall.databasePort" .)
    (include "heimdall.databaseName" .) }}
{{- end }}
```

### 3. Secrets Management (Three Approaches)

**Implement all three patterns from Vulcan**:

1. **Existing Secret** (Production):
   ```yaml
   heimdall:
     existingSecret: "heimdall-production-secrets"
   ```

2. **File-based** (Development):
   ```yaml
   heimdall:
     secretsFiles: ["env/heimdall-secrets.yaml"]
   ```

   Create `generate-heimdall-secrets.sh`:
   ```bash
   #!/bin/bash
   # Generate random secrets for development
   echo "DATABASE_PASSWORD: $(openssl rand -hex 32)"
   echo "JWT_SECRET: $(openssl rand -hex 64)"
   echo "OAUTH_GITLAB_CLIENT_SECRET: $(openssl rand -hex 32)"
   # ... etc
   ```

3. **Inline Values** (CI/CD):
   ```yaml
   heimdall:
     secrets:
       DATABASE_PASSWORD: "..."
       JWT_SECRET: "..."
   ```

**Priority**: `existingSecret` > `secrets` > `secretsFiles`

### 4. Health Probes (Node.js/Sequelize)

**Implement three-probe strategy**:

```yaml
# Startup probe - wait for database migrations
startupProbe:
  httpGet:
    path: /api/v1/health  # Or appropriate health endpoint
    port: 3000
  failureThreshold: 30
  periodSeconds: 10

# Liveness probe - detect crashes
livenessProbe:
  httpGet:
    path: /api/v1/ping  # Fast endpoint
    port: 3000
  periodSeconds: 10
  failureThreshold: 3

# Readiness probe - database connectivity
readinessProbe:
  httpGet:
    path: /api/v1/health/database
    port: 3000
  periodSeconds: 5
  failureThreshold: 3
```

**Note**: Verify Heimdall has these endpoints or create them

### 5. Database Migration Job

**Create `db-migrate-job.yaml`** (Helm hook):

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ include "heimdall.fullname" . }}-migrate
  annotations:
    "helm.sh/hook": post-install,post-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation
spec:
  template:
    spec:
      restartPolicy: Never
      initContainers:
        - name: check-db-ready
          image: postgres:16-alpine
          command: ['sh', '-c', 'until pg_isready -h {{ include "heimdall.databaseHost" . }}; do sleep 2; done']
      containers:
        - name: migrate
          image: {{ .Values.heimdall.image.repository }}:{{ .Values.heimdall.image.tag }}
          command: ['npm', 'run', 'db:migrate']  # Or appropriate Sequelize command
          envFrom:
            - configMapRef:
                name: {{ include "heimdall.fullname" . }}-config
            - secretRef:
                name: {{ .Values.heimdall.existingSecret | default (include "heimdall.fullname" .) }}
```

### 6. OAuth/OIDC Configuration (GitLab Authentication Fix)

**Problem Areas to Investigate**:

1. **Callback URL Construction**:
   ```yaml
   # values.yaml
   heimdall:
     oauth:
       gitlab:
         enabled: true
         clientId: "..."
         # Callback URL should be: https://heimdall.example.com/api/auth/gitlab/callback
         # NOT: https://heimdall.example.com/some-extra-path/api/auth/gitlab/callback
   ```

2. **Ingress Path Configuration**:
   ```yaml
   ingress:
     hosts:
       - host: heimdall.example.com
         paths:
           - path: /
             pathType: Prefix  # NOT ImplementationSpecific or Exact
   ```

3. **Base URL Environment Variable**:
   ```yaml
   # ConfigMap
   HEIMDALL_BASE_URL: "https://{{ .Values.ingress.hosts[0].host }}"
   OAUTH_GITLAB_CALLBACK_URL: "{{ .Values.heimdall.baseUrl }}/api/auth/gitlab/callback"
   ```

4. **Template Helper for OAuth URLs**:
   ```yaml
   {{/*
   Construct OAuth callback URL
   */}}
   {{- define "heimdall.oauthCallbackUrl" -}}
   {{- $protocol := ternary "https" "http" .Values.heimdall.forceSSL -}}
   {{- $host := index .Values.ingress.hosts 0 "host" -}}
   {{- printf "%s://%s/api/auth/%s/callback" $protocol $host .provider }}
   {{- end }}
   ```

### 7. CA Certificates Fix (Issue #33)

**Current Problem**: Hardcoded `certs.pem` filename

**Solution** (Vulcan pattern):

```yaml
# values.yaml
heimdall:
  extraCertificates:
    enabled: false
    configMapName: ""  # Existing ConfigMap
    certificates:
      # Multiple certs with any filename
      corporate-ca.crt: |
        -----BEGIN CERTIFICATE-----
        ...
      dod-root.crt: |
        -----BEGIN CERTIFICATE-----
        ...

# Template: ca-certificates-configmap.yaml
{{- if and .Values.heimdall.extraCertificates.enabled (not .Values.heimdall.extraCertificates.configMapName) }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "heimdall.fullname" . }}-ca-certs
data:
  {{- range $filename, $content := .Values.heimdall.extraCertificates.certificates }}
  {{ $filename }}: |
{{ $content | indent 4 }}
  {{- end }}
{{- end }}

# Deployment: Volume mount and environment variables
volumes:
  - name: ca-certs
    configMap:
      name: {{ .Values.heimdall.extraCertificates.configMapName | default (printf "%s-ca-certs" (include "heimdall.fullname" .)) }}

volumeMounts:
  - name: ca-certs
    mountPath: /etc/ssl/certs/custom
    readOnly: true

env:
  - name: NODE_EXTRA_CA_CERTS
    value: "/etc/ssl/certs/custom"  # Directory, not file
  - name: SSL_CERT_FILE
    value: "/etc/ssl/certs/custom"  # Directory, not file
```

**Or simpler approach**: Mount all certs to `/usr/local/share/ca-certificates/` and run `update-ca-certificates`

### 8. High Availability Configuration

**Add PodDisruptionBudget** (enabled by default):

```yaml
# values.yaml
heimdall:
  replicaCount: 2  # Default to HA

  podDisruptionBudget:
    enabled: true
    minAvailable: 1
```

**Add HPA support**:

```yaml
heimdall:
  autoscaling:
    enabled: false
    minReplicas: 2
    maxReplicas: 10
    targetCPUUtilizationPercentage: 70
```

### 9. Persistent Volume Strategy (Issue #13)

**Current**: Deployment with PVC (creates new PV each time)

**Options**:

**Option A: StatefulSet** (if Heimdall needs persistent local storage):
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "heimdall.fullname" . }}
spec:
  serviceName: {{ include "heimdall.fullname" . }}
  replicas: {{ .Values.heimdall.replicaCount }}
  volumeClaimTemplates:
    - metadata:
        name: heimdall-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: {{ .Values.heimdall.persistence.size }}
```

**Option B: Deployment with External Storage** (if uploads go to S3/object storage):
```yaml
apiVersion: apps/v1
kind: Deployment
# No local persistent storage needed
```

**Recommendation**: Use external object storage (S3, MinIO) for file uploads, keep app stateless

### 10. values.schema.json Creation

**Address Issue #22** - Validation:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["heimdall"],
  "properties": {
    "heimdall": {
      "type": "object",
      "required": ["image"],
      "properties": {
        "image": {
          "type": "object",
          "required": ["repository", "tag"],
          "properties": {
            "repository": { "type": "string" },
            "tag": { "type": "string" },
            "pullPolicy": {
              "type": "string",
              "enum": ["Always", "IfNotPresent", "Never"]
            }
          }
        },
        "env": {
          "type": "object",
          "properties": {
            "NODE_ENV": {
              "type": "string",
              "enum": ["production", "development", "test"]
            }
          },
          "required": ["NODE_ENV"]
        }
      }
    },
    "postgresql": {
      "type": "object",
      "properties": {
        "enabled": { "type": "boolean" }
      }
    },
    "externalDatabase": {
      "type": "object",
      "properties": {
        "host": { "type": "string" },
        "port": { "type": "integer", "minimum": 1, "maximum": 65535 }
      }
    }
  },
  "oneOf": [
    { "properties": { "postgresql": { "properties": { "enabled": { "const": true } } } } },
    {
      "properties": {
        "postgresql": { "properties": { "enabled": { "const": false } } },
        "externalDatabase": { "required": ["host"] }
      }
    }
  ]
}
```

**This ensures**: Either `postgresql.enabled=true` OR `externalDatabase.host` is provided

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Create new `heimdall-helm` repository (or rename existing)
- [ ] Adopt chart structure from Vulcan
- [ ] Create `_helpers.tpl` with database abstraction helpers
- [ ] Implement three secrets approaches
- [ ] Add `values.schema.json`

### Phase 2: Database & Persistence (Week 2)
- [ ] Add Bitnami PostgreSQL subchart dependency
- [ ] Create database migration job (Helm hook)
- [ ] Fix PV reconnection issue (StatefulSet or external storage)
- [ ] Add init container for database readiness

### Phase 3: Health & HA (Week 3)
- [ ] Implement three-probe health check strategy
- [ ] Add PodDisruptionBudget (enabled by default)
- [ ] Add HPA support
- [ ] Configure rolling update strategy

### Phase 4: Security & Configuration (Week 4)
- [ ] Fix CA certificates dynamic filename issue (#33)
- [ ] Add NetworkPolicy support
- [ ] Enhance security contexts
- [ ] Add ServiceAccount with cloud IAM annotations

### Phase 5: OAuth/OIDC Fix (Week 5)
- [ ] Debug GitLab authentication URI issue
- [ ] Create OAuth callback URL helper templates
- [ ] Test with multiple providers (GitLab, GitHub, Okta)
- [ ] Document OIDC configuration patterns

### Phase 6: Documentation & Testing (Week 6)
- [ ] Create comprehensive CLAUDE.md (Heimdall version)
- [ ] Auto-generate README.md using helm-docs
- [ ] Add NOTES.txt with post-install instructions
- [ ] Create Helm tests (`templates/tests/`)
- [ ] Update all issue documentation (#8)

### Phase 7: CI/CD & Release (Week 7)
- [ ] Set up GitHub Actions for chart releases
- [ ] Publish to GitHub Pages
- [ ] Add Artifact Hub annotations
- [ ] Create CHANGELOG.md
- [ ] Tag v1.0.0 release

## Key Differences: Heimdall vs Vulcan

### Heimdall-Specific Requirements

1. **Database**: Node.js/Sequelize vs Rails/ActiveRecord
   - Different migration commands
   - Different database URL format (might be same)
   - Different health check endpoints

2. **File Uploads**: Heimdall handles eval file uploads
   - Consider external storage (S3, MinIO)
   - Or use StatefulSet with persistent storage
   - Configure upload size limits in ingress

3. **OAuth Providers**: Multiple OIDC providers
   - GitLab, GitHub, Google, Okta, LDAP
   - Each needs callback URL configuration
   - Template helpers critical for correctness

4. **API vs Full Stack**: Heimdall is API + frontend
   - Different health check endpoints
   - May need separate frontend/backend services
   - Consider serving static assets from CDN

### Shared Patterns (Copy from Vulcan)

- Bitnami PostgreSQL subchart
- Three secrets approaches
- Health probe strategy
- Helm hooks for migrations
- PodDisruptionBudget
- NetworkPolicy
- ServiceMonitor
- Ingress with TLS
- values.schema.json
- CI/CD release workflow

## Migration Testing Checklist

### Pre-Migration
- [ ] Backup existing Heimdall database
- [ ] Document current configuration
- [ ] Test current deployment works
- [ ] List all OAuth providers in use

### During Migration
- [ ] Test with Bitnami PostgreSQL subchart
- [ ] Verify database migrations run correctly
- [ ] Test all three secrets approaches
- [ ] Verify health probes work
- [ ] Test OAuth with GitLab (debug URI issue)
- [ ] Test OAuth with GitHub
- [ ] Test OAuth with Okta
- [ ] Test file upload functionality
- [ ] Verify CA certificates work with custom certs

### Post-Migration
- [ ] Compare old vs new chart resource usage
- [ ] Verify zero-downtime upgrades work
- [ ] Test rollback functionality
- [ ] Load test with realistic traffic
- [ ] Security scan with checkov
- [ ] Update all documentation

## GitLab Authentication Deep Dive

### Known Issue
"GitLab Authentication appends extra URI part"

### Investigation Steps

1. **Check Current Callback URL**:
   ```bash
   kubectl exec -it <heimdall-pod> -- env | grep OAUTH
   # Look for: OAUTH_GITLAB_CALLBACK_URL
   ```

2. **Check Ingress Path**:
   ```bash
   kubectl get ingress -n heimdall -o yaml
   # Look for: pathType and path configuration
   ```

3. **Compare Working vs Broken**:
   - GitHub OAuth callback (working): `https://heimdall.example.com/api/auth/github/callback`
   - GitLab OAuth callback (broken): `https://heimdall.example.com/???/api/auth/gitlab/callback`
   - What is the extra `???` path component?

4. **Potential Root Causes**:

   **A. Ingress rewrite annotation**:
   ```yaml
   # Check for this in ingress annotations
   nginx.ingress.kubernetes.io/rewrite-target: /some-path/$1
   ```

   **B. Base URL misconfiguration**:
   ```yaml
   # ConfigMap should have:
   HEIMDALL_BASE_URL: "https://heimdall.example.com"
   # NOT:
   HEIMDALL_BASE_URL: "https://heimdall.example.com/some-path"
   ```

   **C. GitLab-specific template logic**:
   ```yaml
   # Check if GitLab callback has different template than others
   OAUTH_GITLAB_CALLBACK_URL: {{ .Values.gitlab.customPath }}/api/auth/gitlab/callback
   ```

   **D. PathType issue**:
   ```yaml
   paths:
     - path: /
       pathType: ImplementationSpecific  # WRONG - may cause issues
   # Should be:
     - path: /
       pathType: Prefix  # CORRECT
   ```

### Recommended Fix

**Template Helper** for all OAuth providers:

```yaml
{{/*
Generate OAuth callback URL
Usage: {{ include "heimdall.oauthCallback" (dict "root" . "provider" "gitlab") }}
*/}}
{{- define "heimdall.oauthCallback" -}}
{{- $root := .root -}}
{{- $provider := .provider -}}
{{- $protocol := ternary "https" "http" $root.Values.heimdall.forceSSL -}}
{{- $host := index $root.Values.ingress.hosts 0 "host" | default "localhost" -}}
{{- $basePath := $root.Values.heimdall.basePath | default "" | trimSuffix "/" -}}
{{- printf "%s://%s%s/api/auth/%s/callback" $protocol $host $basePath $provider -}}
{{- end }}
```

**Usage in ConfigMap**:
```yaml
OAUTH_GITLAB_CALLBACK_URL: {{ include "heimdall.oauthCallback" (dict "root" . "provider" "gitlab") }}
OAUTH_GITHUB_CALLBACK_URL: {{ include "heimdall.oauthCallback" (dict "root" . "provider" "github") }}
OAUTH_GOOGLE_CALLBACK_URL: {{ include "heimdall.oauthCallback" (dict "root" . "provider" "google") }}
```

## Success Criteria

Chart modernization is complete when:

- [ ] All 8 open issues resolved
- [ ] Chart passes `helm lint --strict`
- [ ] Values pass `values.schema.json` validation
- [ ] All Helm tests pass (`helm test`)
- [ ] GitLab OAuth works without URI issues
- [ ] Zero-downtime upgrades verified
- [ ] Documentation complete (CLAUDE.md, README.md, NOTES.txt)
- [ ] CI/CD pipeline publishes to GitHub Pages
- [ ] Chart achieves "Verified Publisher" status on Artifact Hub
- [ ] Successfully deployed in production environment

## Next Steps

1. **Create CLAUDE.md for Heimdall repository** (similar to Vulcan's)
2. **Set up local development cluster** for testing
3. **Begin Phase 1** (Foundation)
4. **Debug GitLab OAuth issue** in parallel
5. **Document findings** in new issues/PRs

## Resources

- Vulcan Helm Chart: https://github.com/mitre/vulcan-helm
- Heimdall App: https://github.com/mitre/heimdall2
- Bitnami PostgreSQL Chart: https://github.com/bitnami/charts/tree/main/bitnami/postgresql
- Helm Best Practices: https://helm.sh/docs/chart_best_practices/
