# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Helm chart for deploying MITRE SAF Heimdall to Kubernetes. Heimdall is a Node.js/Sequelize web application for visualizing security scan results from InSpec and other security tools. The chart deploys:
- Heimdall application container (mitre/heimdall2)
- PostgreSQL database (will migrate to Bitnami subchart)
- Optional ingress, autoscaling, persistent storage, and monitoring

**Chart Version**: 3.3.3 (current) → 1.0.0 (target after modernization)
**App Version**: release-latest
**Helm Version**: 4.x (Helm v4.0.0 released November 2025)
**Chart API Version**: v2 (compatible with Helm 3 and 4, v3 coming soon)

## Repository Context

**Repository Renamed**: `heimdall2-helm` → `heimdall-helm` (December 2025)
- GitHub automatically redirects all old URLs
- Chart name changes from `heimdall2` to `heimdall` in v1.0.0
- Directory currently `heimdall2/` will be renamed to `heimdall/`

## Chart Repository

- **Published Charts**: https://mitre.github.io/heimdall-helm
- **Source Code**: https://github.com/mitre/heimdall-helm
- **Artifact Hub**: https://artifacthub.io/packages/helm/mitre/heimdall
- **Application Repo**: https://github.com/mitre/heimdall2

## Modernization Status

**Current State**: Legacy chart structure (v3.3.3)
**Target State**: Apply Vulcan Helm chart patterns (v1.0.0)

This repository is undergoing modernization to align with industry best practices. See:
- `HEIMDALL-MIGRATION-PLAN.md` - Detailed modernization roadmap
- `vulcan-helm/CLAUDE.md` - Reference implementation patterns
- `.beads/` - Task tracking with Beads

## Project Management

### Beads Task Tracker

This project uses **Beads** for distributed, git-backed task management:

```bash
# View ready tasks
bd ready

# List all tasks
bd list

# Show task details
bd show <task-id>

# Mark task complete
bd done <task-id>

# Create new task
bd create "Task description" -p 0

# Add dependency (child blocked by parent)
bd dep add <child-id> <parent-id>
```

**Task Organization**:
- **Epic-level**: Phase tasks (Phase 1, Phase 2, etc.)
- **Task-level**: Specific implementation work
- **Subtask-level**: Granular steps within tasks

### Context Preservation

**Key Files** (never delete, always maintain):
- `CLAUDE.md` - This file, Claude Code guidance
- `HEIMDALL-MIGRATION-PLAN.md` - Modernization roadmap
- `SESSION-*.md` - Session notes (incrementing numbers)
- `.beads/` - Task database (git-backed)

## Reference Materials

### Vulcan Helm Chart (Pattern Source)

Located at: `/Users/alippold/github/mitre/vulcan-helm`

**Key files to reference**:
- `vulcan-helm/CLAUDE.md` - Comprehensive Helm best practices
- `vulcan-helm/vulcan/templates/_helpers.tpl` - Template helper patterns
- `vulcan-helm/vulcan/values.yaml` - Values organization
- `vulcan-helm/vulcan/templates/vulcan-secrets.yaml` - Three secrets approaches
- `vulcan-helm/vulcan/templates/db-migrate-job.yaml` - Migration job pattern
- `vulcan-helm/generate-vulcan-secrets.sh` - Secrets generation script

**Patterns to Copy**:
1. Bitnami PostgreSQL subchart dependency
2. Three secrets approaches (existing, files, inline)
3. Health probe strategy (startup, liveness, readiness)
4. Template helpers for database abstraction
5. Helm hooks for migrations
6. PodDisruptionBudget (enabled by default)
7. values.schema.json validation
8. CA certificates dynamic loading

## Current Chart Structure

```
heimdall-helm/
├── heimdall2/                  # Will rename to heimdall/
│   ├── Chart.yaml
│   ├── values.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── NOTES.txt
│       ├── heimdall-configmap.yaml
│       ├── heimdall-secrets.yaml
│       ├── heimdall-statefulset.yaml
│       ├── heimdall-service.yaml
│       ├── postgres-*.yaml     # To be replaced with Bitnami subchart
│       └── ...
├── start-heimdall2.sh          # Installation helper
├── delete_heimdall2.sh         # Cleanup helper
├── sops/                       # SOPS secrets management
└── README.md
```

## Known Issues (GitHub Issues)

See full analysis in `HEIMDALL-MIGRATION-PLAN.md`. Key issues:

1. **Issue #33**: CA cert filename hardcoded to `certs.pem`
2. **Issue #29**: Init container needs UBI 9 update
3. **Issue #24**: Database password should use `stringData`
4. **Issue #22**: Need values.schema.json validation
5. **Issue #13**: PV reconnection broken (creates new PV each time)
6. **Issue #9**: Need Helm tests
7. **Issue #8**: Documentation needs updates
8. **Issue #6**: Duplicate host configuration in ingress

## GitLab OAuth Authentication Bug

**Problem**: GitLab authentication appends extra URI part to callback URL
**Status**: Under investigation

**Likely Causes**:
- Ingress path configuration (PathType issue)
- Base URL environment variable misconfigured
- Callback URL template logic specific to GitLab
- Ingress rewrite annotations

**Investigation Location**: `HEIMDALL-MIGRATION-PLAN.md` → "GitLab Authentication Deep Dive"

## Helm v4 Compatibility

**Released**: November 12, 2025 (Helm's 10th anniversary)
**Status**: Stable, production-ready

### Key Features for Chart Developers
- **Chart API v2 Fully Supported**: Existing charts work unchanged
- **Chart API v3 Coming**: Groundwork laid for new features during Helm 4 lifecycle
- **Server-Side Apply**: Modern Kubernetes support
- **WebAssembly Plugins**: Cross-platform extensibility
- **Enhanced Security**: Improved chart security features
- **Backward Compatible**: Helm 3 charts work without modification

### Chart.yaml for Helm v4
```yaml
apiVersion: v2  # Continues to work in Helm 4
# apiVersion: v3  # Coming soon - wait for official release
```

**Our Strategy**: Build chart with `apiVersion: v2` (works in both Helm 3 and 4), prepare for v3 when available.

## Helm Best Practices Reference

For comprehensive Helm chart best practices, see:
- `vulcan-helm/CLAUDE.md` → "Helm Chart Best Practices (Knowledge Base for SAF Charts)"
- [Official Helm v4 Docs](https://helm.sh/docs/)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)

**Quick Reference**:
- Use Bitnami subcharts for databases
- Support three secrets approaches
- Implement three-probe health strategy
- Enable PodDisruptionBudget by default
- Create values.schema.json for validation
- Use Helm hooks for migrations
- Template helpers for abstraction
- Semantic versioning (MAJOR.MINOR.PATCH)
- Target Helm v4 (backward compatible with v3)

## Essential Helm Commands

### Chart Development

```bash
# Navigate to chart directory
cd /Users/alippold/github/mitre/heimdall-helm

# Lint chart
helm lint ./heimdall2
helm lint ./heimdall2 --strict

# Template rendering (preview manifests)
helm template heimdall ./heimdall2
helm template heimdall ./heimdall2 --debug

# Validate with kubectl
helm template heimdall ./heimdall2 | kubectl apply --dry-run=client -f -

# Update dependencies (after adding Bitnami PostgreSQL)
helm dependency update ./heimdall2
helm dependency build ./heimdall2
```

### Installation and Testing

```bash
# Install to test cluster
helm install heimdall ./heimdall2 -n heimdall --create-namespace

# Upgrade
helm upgrade heimdall ./heimdall2 -n heimdall

# Uninstall
helm uninstall heimdall -n heimdall

# Check status
helm status heimdall -n heimdall

# Get values
helm get values heimdall -n heimdall
helm get values heimdall -n heimdall --all
```

### Debugging

```bash
# Check pods
kubectl get pods -n heimdall
kubectl describe pod -n heimdall <pod-name>
kubectl logs -n heimdall <pod-name> -f

# Check events
kubectl get events -n heimdall --sort-by='.lastTimestamp'

# Port forward
kubectl port-forward -n heimdall deployment/heimdall 3000:3000
```

## Modernization Workflow

### Phase-Based Approach

Work follows 7 phases (see `HEIMDALL-MIGRATION-PLAN.md`):

1. **Phase 1: Foundation** - Chart structure, helpers, secrets
2. **Phase 2: Database & Persistence** - Bitnami PostgreSQL, migrations
3. **Phase 3: Health & HA** - Probes, PDB, HPA
4. **Phase 4: Security & Configuration** - CA certs, NetworkPolicy
5. **Phase 5: OAuth/OIDC Fix** - GitLab authentication debug
6. **Phase 6: Documentation & Testing** - CLAUDE.md, tests, README
7. **Phase 7: CI/CD & Release** - GitHub Actions, v1.0.0 release

### Task Management Pattern

```bash
# Start of session
bd ready                        # See what's ready to work on
bd show <task-id>               # Review task details

# During work
# Mark task in_progress in Beads
# Update session notes

# End of work
bd done <task-id>               # Mark complete
# Create new session file SESSION-N.md
# Commit and push
```

### Branch Strategy

```bash
# Create feature branches for phases
git checkout -b phase-1-foundation
# Work on Phase 1 tasks
git commit -m "feat: Phase 1 foundation complete"
git push origin phase-1-foundation

# Create PR for review
gh pr create --title "Phase 1: Foundation" --body "..."

# After merge, move to next phase
git checkout main
git pull
git checkout -b phase-2-database
```

## Heimdall-Specific Considerations

### Application Architecture

- **Tech Stack**: Node.js, Sequelize ORM, PostgreSQL
- **Port**: 3000
- **Health Endpoints**: TBD (need to verify what exists)
- **File Uploads**: Security scan result files (JSON, XML)
- **Storage**: Database + optional file uploads

### Database Migrations

**Current**: Unknown migration approach
**Target**: Sequelize migrations via Helm hook

```yaml
# db-migrate-job.yaml (to create)
command: ['npx', 'sequelize-cli', 'db:migrate']
# Or: ['npm', 'run', 'db:migrate']
```

### OAuth/OIDC Providers

Heimdall supports multiple authentication providers:
- Local authentication
- GitLab OAuth (**has bug**)
- GitHub OAuth
- Google OAuth
- Okta OIDC
- LDAP

**Configuration**: Environment variables for each provider
**Callback URLs**: Must be templated correctly (see GitLab bug)

### Environment Variables

**Required** (from current chart):
- `NODE_ENV` - production/development
- `DATABASE_HOST` - PostgreSQL hostname
- `DATABASE_PORT` - PostgreSQL port (5432)
- `DATABASE_NAME` - Database name
- `DATABASE_USERNAME` - Database user
- `DATABASE_PASSWORD` - Database password (secret)
- `JWT_SECRET` - Session signing key (secret)
- `OAUTH_*_CLIENT_ID` - OAuth client IDs
- `OAUTH_*_CLIENT_SECRET` - OAuth secrets (secret)

### File Upload Storage

**Options**:
1. **Ephemeral** (no PV) - Files in database only
2. **PersistentVolume** - Local storage (current, broken)
3. **Object Storage** - S3/MinIO (recommended for production)

**Decision Point**: Need to determine Heimdall's file storage requirements

## Development Environment Setup

### Prerequisites

```bash
# Kubernetes cluster (kind, minikube, or cloud)
kind create cluster --name heimdall-dev

# Helm v4.x (or v3.x minimum)
helm version
# Should show: version.BuildInfo{Version:"v4.0.0"...}

# Upgrade Helm to v4 if needed
# macOS: brew upgrade helm
# Linux: Download from https://github.com/helm/helm/releases

# Beads (already installed)
bd --version

# kubectl
kubectl version --client
```

### Local Testing Cluster

```bash
# Create kind cluster with ingress
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

# Install ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

# Wait for ingress ready
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
```

## Testing Strategy

### Pre-Commit Checks

```bash
# Lint
helm lint ./heimdall2 --strict

# Template validation
helm template heimdall ./heimdall2 | kubectl apply --dry-run=client -f -

# Schema validation (after creating values.schema.json)
# Automatic during lint
```

### Integration Testing

```bash
# Install to test cluster
helm install heimdall ./heimdall2 -n heimdall-test --create-namespace

# Verify deployment
kubectl get pods -n heimdall-test
kubectl get svc -n heimdall-test

# Run Helm tests (after creating)
helm test heimdall -n heimdall-test

# Test upgrade
helm upgrade heimdall ./heimdall2 -n heimdall-test

# Cleanup
helm uninstall heimdall -n heimdall-test
kubectl delete namespace heimdall-test
```

### OAuth Testing Checklist

For each provider (especially GitLab):
- [ ] Verify callback URL is correct
- [ ] Test login flow
- [ ] Verify redirect after authentication
- [ ] Check user creation/mapping
- [ ] Test logout

## Git Workflow

### Commit Message Convention

Follow conventional commits:

```bash
# Types
feat:     # New feature
fix:      # Bug fix
docs:     # Documentation only
style:    # Formatting, no code change
refactor: # Code change that neither fixes a bug nor adds a feature
test:     # Adding tests
chore:    # Maintenance tasks

# Examples
git commit -m "feat: add Bitnami PostgreSQL subchart dependency"
git commit -m "fix: CA certificate filename now dynamic (closes #33)"
git commit -m "docs: update CLAUDE.md with modernization workflow"
```

### Commit Signatures

```bash
# Always use human authorship
git commit -m "feat: implement three secrets approaches

Authored by: Aaron Lippold <lippold@gmail.com>"
```

**Never use**:
- Claude Code generated signatures
- AI co-author attributions

## Session Management

### Creating Session Files

```bash
# Always create NEW session files, never overwrite
# Format: SESSION-<number>.md
# Example progression:
SESSION-001.md  # Initial modernization planning
SESSION-002.md  # Phase 1 foundation work
SESSION-003.md  # GitLab OAuth investigation
# ... etc
```

### Session File Template

```markdown
# SESSION-XXX: <Brief Description>

**Date**: 2025-MM-DD
**Phase**: Phase N - <Phase Name>
**Focus**: <Primary goal of this session>

## Work Completed

- Task 1
- Task 2

## Decisions Made

- Decision 1 with rationale
- Decision 2 with rationale

## Issues Encountered

- Issue and resolution
- Blocker and workaround

## Next Steps

- [ ] Task A
- [ ] Task B

## Beads Tasks Updated

- heimdall-helm-XXXX: Status changed to <status>
- heimdall-helm-YYYY: Created for <reason>

## References

- File paths modified
- Documentation consulted
```

## Important Notes

- **Never delete session files** - They preserve context across work sessions
- **Always check Beads before starting** - `bd ready` shows what's next
- **Reference Vulcan patterns** - Don't reinvent, adapt proven solutions
- **Test incrementally** - Each phase should be deployable
- **Document decisions** - Capture "why" not just "what"
- **Update CLAUDE.md** - Keep this file current as you learn

## Common Patterns to Copy from Vulcan

### 1. Template Helper for Database
```yaml
{{/*
Get database host - abstraction for subchart vs external
*/}}
{{- define "heimdall.databaseHost" -}}
{{- if .Values.postgresql.enabled }}
{{- include "heimdall.postgresql.fullname" . }}
{{- else }}
{{- .Values.externalDatabase.host }}
{{- end }}
{{- end }}
```

### 2. Three Secrets Approaches
```yaml
# Priority: existingSecret > secrets > secretsFiles
{{- if .Values.heimdall.existingSecret }}
# Use existing secret
{{- else if .Values.heimdall.secrets }}
# Use inline secrets
{{- else }}
# Use file-based secrets
{{- end }}
```

### 3. Health Probes
```yaml
startupProbe:   # Migrations + initialization
livenessProbe:  # Process alive
readinessProbe: # Database connected
```

### 4. Helm Hook for Migrations
```yaml
annotations:
  "helm.sh/hook": post-install,post-upgrade
  "helm.sh/hook-weight": "-5"
  "helm.sh/hook-delete-policy": before-hook-creation
```

## Troubleshooting

### Beads Issues

```bash
# If beads commands fail
bd doctor --fix

# If database corrupted
rm -rf .beads/
bd init
```

### Helm Issues

```bash
# Template rendering errors
helm template heimdall ./heimdall2 --debug

# Dependency issues
rm -rf heimdall2/charts/ heimdall2/Chart.lock
helm dependency update ./heimdall2

# Installation failures
kubectl get events -n heimdall --sort-by='.lastTimestamp'
helm get manifest heimdall -n heimdall
```

## References

- [Vulcan Helm Chart CLAUDE.md](file:///Users/alippold/github/mitre/vulcan-helm/CLAUDE.md)
- [HEIMDALL-MIGRATION-PLAN.md](file:///Users/alippold/github/mitre/heimdall-helm/HEIMDALL-MIGRATION-PLAN.md)
- [Helm Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Bitnami Charts](https://github.com/bitnami/charts)
- [Artifact Hub](https://artifacthub.io/)
- [Beads Documentation](https://github.com/steveyegge/beads)
