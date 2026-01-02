# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Documentation and Communication Style - NO MARKETING BULLSHIT

**CRITICAL - THIS IS WORK, NOT A SALES PITCH**

People see AI-generated marketing language and immediately distrust it. Write like a human helping another human get work done.

**NEVER use:**
- "Production-ready", "battle-tested", "enterprise-grade" - marketing bullshit
- "Built following best practices" - empty praise
- "Comprehensive", "robust", "powerful" - meaningless adjectives
- "Millions of deployments" - who gives a fuck
- Feel-good language trying to validate or praise
- Explaining WHY things are good - just state what they ARE
- References to other projects unless directly relevant (no "like Vulcan" comparisons)

**ALWAYS:**
- State facts: what it is, what it does
- Be direct and concise
- Link to relevant standards/patterns if they're actually useful for understanding
- Assume the reader knows what they need - just tell them how to get it
- Write like you're helping someone do work, not selling them something

**Why:** The work speaks for itself. If working code isn't enough to sell someone, we don't want to work with them.

## Git Safety Protocol

**CRITICAL - READ BEFORE ANY GIT OPERATION:**

- **ALWAYS** run `git status --short` before ANY `git commit`
- **NEVER** commit without showing the user what will be committed
- **For code files**: User MUST review `git diff --staged` before commit
- **For documentation**: Show `git status --short` before commit
- **ONE git operation at a time** - verify success before next operation
- **When in doubt**: Prepare changes, let USER run git commands

**Reason**: Previous incident where commit deleted files instead of renaming them due to skipping verification step.

## CRITICAL ENVIRONMENT INFORMATION - READ FIRST

**DOCUMENTATION SERVER RUNNING ON PORT 3000**
- Nuxt documentation site runs on http://localhost:3000
- **NEVER** use port 3000 for port-forwarding Heimdall or any other service
- Use port 8080 or other ports for Heimdall testing: `kubectl port-forward -n heimdall svc/heimdall 8080:3000`

**LOCAL HEIMDALL IMAGE FOR KIND**
- kind cluster on Apple Silicon requires ARM64 images
- Local image available: `heimdall-app:arm64-test`
- Already loaded in kind cluster: `heimdall-test`
- **ALWAYS** use local image in test values, NOT `mitre/heimdall2:release-latest` (x86 only)

**GITLAB OAUTH ISSUE #7542 CONTEXT**
- This has been investigated SEVEN times already
- Root cause: USER CONFIGURATION ERROR - setting `EXTERNAL_URL` with `/authn` path
- Our Helm chart ALREADY prevents this with:
  1. values.schema.json regex: `^https?://[^/]+$`
  2. ConfigMap template validation that fails if `/authn` is in URL
- DO NOT add warnings to docs without TESTING FIRST
- Testing plan: Deploy Heimdall with OAuth mock server, verify callback URLs work correctly

## Project Overview

This is a **Helm chart** for deploying **MITRE SAF Heimdall** to Kubernetes. Heimdall is a Node.js/Sequelize application for visualizing security scan results from InSpec and other tools.

**Chart Version**: 1.0.0 (modernized from v3.3.3)
**App Version**: release-latest
**Helm Version**: 3.x or 4.x (fully compatible)

## Quick Links

- **Chart Repository**: https://mitre.github.io/heimdall-helm
- **Source Code**: https://github.com/mitre/heimdall-helm
- **Application Repo**: https://github.com/mitre/heimdall2
- **Artifact Hub**: https://artifacthub.io/packages/helm/mitre/heimdall

## Repository Context

**Repository Renamed** (December 2025): `heimdall2-helm` → `heimdall-helm`
- GitHub automatically redirects all old URLs
- Chart name changes from `heimdall2` to `heimdall` in v1.0.0
- Chart directory: `heimdall/` (renamed from `heimdall2/`)

## Working Directory

**CRITICAL**: Always verify you're in the correct directory:

```bash
pwd  # Should show: /Users/alippold/github/mitre/heimdall-helm
git branch --show-current  # Should show: develop (or feature branch)
```

## Modernization Project

**Current Status**: Applying Vulcan Helm chart patterns to modernize Heimdall chart

**Documentation**:
- `HEIMDALL-MIGRATION-PLAN.md` - Detailed modernization roadmap (7 phases)
- `PHASE1-COMPLETE.md` - Phase 1 completion summary
- `docs/` - Nuxt UI documentation site (user-facing)
- `docs/` (this folder) - Technical reference documentation

**Reference Implementation**: `/Users/alippold/github/mitre/vulcan-helm`
- Study Vulcan's patterns before implementing in Heimdall
- Copy proven solutions, don't reinvent
- Key file: `vulcan-helm/CLAUDE.md` (comprehensive Helm best practices)

## Essential Commands

### Chart Development

```bash
# Validate chart
helm lint ./heimdall --strict

# Preview manifests
helm template heimdall ./heimdall

# Update dependencies (Bitnami PostgreSQL)
helm dependency update ./heimdall

# Install locally
helm install heimdall ./heimdall -n heimdall --create-namespace

# Upgrade
helm upgrade heimdall ./heimdall -n heimdall

# Uninstall
helm uninstall heimdall -n heimdall
```

**Full command reference**: See `docs/HELM-REFERENCE.md`

### Development Environment

```bash
# Create kind cluster for testing
kind create cluster --name heimdall-dev

# Port forward to access locally
kubectl port-forward -n heimdall statefulset/heimdall 3000:3000

# Access: http://localhost:3000
```

**Full setup guide**: See `docs/DEVELOPMENT.md`

## Beads Task Management

This project uses **Beads** (git-backed task tracker) for work organization:

```bash
# View ready tasks (no blockers)
bd ready

# List all tasks
bd list

# Show task details
bd show <task-id>

# Mark task complete
bd close <task-id>

# Create new task
bd create --title="Task description" --type=task --priority=2
```

**Task Organization**:
- Epic-level: Phase 1-7 (see HEIMDALL-MIGRATION-PLAN.md)
- Task-level: Specific implementation work
- Subtasks: Granular steps

**CRITICAL**: Always check `bd ready` before starting work!

## Chart Structure

```
heimdall-helm/
├── CLAUDE.md                       # This file
├── HEIMDALL-MIGRATION-PLAN.md      # 7-phase roadmap
├── docs/                           # Technical reference
│   ├── HELM-REFERENCE.md           # Helm commands
│   ├── DEVELOPMENT.md              # Dev environment setup
│   ├── TESTING.md                  # Testing strategies
│   └── TROUBLESHOOTING.md          # Common issues
├── docs/                           # Nuxt UI documentation site
│   └── content/4.helm-chart/       # Phase 1 documentation
├── heimdall/                       # Chart directory
│   ├── Chart.yaml                  # v1.0.0, Bitnami PostgreSQL dependency
│   ├── Chart.lock                  # Locked dependency versions
│   ├── values.yaml                 # Configuration
│   ├── values.schema.json          # JSON Schema validation
│   ├── env/
│   │   ├── heimdallconfig.yaml     # Non-sensitive env vars
│   │   └── heimdall-secrets.yaml   # Secrets (gitignored, generated)
│   ├── charts/                     # Downloaded dependencies (gitignored)
│   └── templates/
│       ├── _helpers.tpl            # Database abstraction helpers
│       ├── configmap.yaml          # Environment ConfigMap
│       ├── heimdall-secrets.yaml   # Three secrets approaches
│       ├── heimdall-statefulset.yaml
│       ├── heimdall-service.yaml
│       ├── db-migrate-job.yaml     # Sequelize migrations (Phase 2)
│       └── ...
├── generate-heimdall-secrets.sh    # Generate random secrets
└── .beads/                         # Task database (git-backed)
```

## Phase Progress

**✅ Phase 1: Foundation (COMPLETE)**
- Chart structure and naming (v1.0.0)
- Template helpers for database abstraction
- values.schema.json validation (95+ variables)
- Three-approach secrets management
- ConfigMap with envFrom pattern
- StatefulSet simplification
- Nuxt UI documentation (7 pages)

**✅ Phase 2: Database & Persistence (COMPLETE)**
- Bitnami PostgreSQL subchart integration
- Removed standalone PostgreSQL templates
- Values-driven configuration (no hardcoding)
- Database helpers using configurable values
- Chart.lock committed for reproducible builds

**⏳ Phase 2: Database & Persistence (IN PROGRESS - remaining work)**
- Init container for PostgreSQL readiness check
- db-migrate-job.yaml for Sequelize migrations
- Health probes (startup/liveness/readiness)

**❌ Phases 3-7** (pending): See HEIMDALL-MIGRATION-PLAN.md

## Key Design Decisions

### 1. Bitnami PostgreSQL Subchart

**Why**: Battle-tested, millions of deployments, built-in HA/backup/monitoring

**Configuration**:
```yaml
# Embedded (default)
postgresql:
  enabled: true
  auth:
    database: heimdall
    username: postgres
    password: ""  # Auto-generated

# External database
postgresql:
  enabled: false
externalDatabase:
  host: db.example.com
  port: 5432
  database: heimdall_production
  username: heimdall_app
```

### 2. Three Secrets Approaches

**Priority**: `existingSecret` > `secrets` > `secretsFiles`

1. **Existing Secret** (Production): External Secrets Operator, Vault, Sealed Secrets
2. **File-based** (Development): `env/heimdall-secrets.yaml` (auto-generated, gitignored)
3. **Inline** (CI/CD): `--set heimdall.secrets.JWT_SECRET="..."`

### 3. Template Helpers for Database Abstraction

Helpers abstract embedded vs external database:
- `heimdall.databaseHost` - Returns PostgreSQL service name or external host
- `heimdall.databasePort` - Returns port from values (configurable)
- `heimdall.databaseName` - Returns database name
- `heimdall.databaseUsername` - Returns username from values (configurable)

**CRITICAL**: ALL values must be configurable via values.yaml with sensible defaults. NEVER hardcode values.

### 4. envFrom Pattern

**Old** (337 individual env entries):
```yaml
env:
  - name: NODE_ENV
    value: {{ .Values.nodeEnv }}
  - name: DATABASE_HOST
    value: {{ include "heimdall.databaseHost" . }}
  # ... 335 more
```

**New** (23 lines, envFrom):
```yaml
envFrom:
  - configMapRef:
      name: {{ include "heimdall.fullname" . }}-config
  - secretRef:
      name: {{ ternary .Values.heimdall.existingSecret ... }}
```

**Result**: 65% code reduction, cleaner templates, easier maintenance

## Critical Development Rules

### 1. Helm Best Practices

**NEVER HARDCODE VALUES** - Everything must be configurable via values.yaml with defaults
- ❌ `port: 5432` (hardcoded)
- ✅ `port: {{ .Values.postgresql.primary.service.ports.postgresql | default 5432 }}`

**Chart.lock MUST be committed** - Ensures reproducible builds
- Use `git add -f heimdall/Chart.lock` if gitignored

**Test after every change**:
```bash
helm lint ./heimdall --strict
helm template heimdall ./heimdall | kubectl apply --dry-run=client -f -
```

### 2. Git Workflow

**NEVER use `git add -A` or `git add .`** - Add files individually

**Always verify directory first**:
```bash
pwd && git branch --show-current
```

**Use conventional commits**:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `chore:` - Maintenance tasks

**Commit signatures** - Use human authorship:
```
Authored by: Aaron Lippold <lippold@gmail.com>
```

**NO Claude Code signatures** in commits

### 3. Documentation

**Nuxt Content MDC Syntax** (for docs/content/ files):
- Title from frontmatter `title:` field (NOT `#` markdown headers)
- Use `##` for first-level sections
- MDC components: `::callout`, `::card-group`, `::field-group`, `::steps`
- Study examples in `docs/content/` before writing

**Session Files** (SESSION-*.md):
- Always create NEW session files, never overwrite
- Incrementing numbers: SESSION-001.md, SESSION-002.md, etc.
- Track decisions, issues, next steps

### 4. Context Preservation

**Never delete these files**:
- `CLAUDE.md` - This file
- `HEIMDALL-MIGRATION-PLAN.md` - 7-phase roadmap
- `SESSION-*.md` - Session notes
- `.beads/` - Task database
- `PHASE1-COMPLETE.md` - Phase completion summaries

**Always read CLAUDE.md at START of every session** before doing any work

## Reference Documentation

Instead of duplicating information here, see:

- **Helm Commands**: `docs/HELM-REFERENCE.md` - Comprehensive command reference
- **Development Setup**: `docs/DEVELOPMENT.md` - Environment setup, kind, minikube, testing workflow
- **Testing Strategies**: `docs/TESTING.md` - Syntax validation, integration tests, configuration testing
- **Troubleshooting**: `docs/TROUBLESHOOTING.md` - Common issues and solutions
- **Helm Best Practices**: `vulcan-helm/CLAUDE.md` - Complete best practices knowledge base
- **Migration Plan**: `HEIMDALL-MIGRATION-PLAN.md` - 7 phases with detailed tasks

## Heimdall-Specific Notes

### Application Architecture

- **Tech Stack**: Node.js, Sequelize ORM, PostgreSQL
- **Port**: 3000
- **Health Endpoints**: `/up`, `/health_check`, `/health_check/database`
- **Migrations**: Sequelize migrations via `npx sequelize-cli db:migrate`

### Authentication Providers

- Local authentication
- GitLab OAuth (**has known bug** - callback URL issue)
- GitHub OAuth
- Google OAuth
- Okta OIDC
- LDAP

**GitLab OAuth Bug**: Under investigation, see HEIMDALL-MIGRATION-PLAN.md → "GitLab Authentication Deep Dive"

### Environment Variables

**Required**:
- `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USERNAME`, `DATABASE_PASSWORD`
- `JWT_SECRET` - Session signing (secret)
- `NODE_ENV` - production/development

**OAuth/OIDC** (provider-specific):
- `OAUTH_*_CLIENT_ID`, `OAUTH_*_CLIENT_SECRET`
- `OIDC_*` configuration variables

See `heimdall/env/heimdallconfig.yaml` for full list

## Common Workflows

### 1. Starting Work

```bash
# Verify location
cd /Users/alippold/github/mitre/heimdall-helm
pwd && git branch --show-current

# Check what's ready
bd ready

# Show task details
bd show <task-id>

# Mark task in_progress
bd update <task-id> --status=in_progress
```

### 2. Making Changes

```bash
# Edit templates
vim heimdall/templates/heimdall-statefulset.yaml

# Lint after changes
helm lint ./heimdall --strict

# Template to verify
helm template heimdall ./heimdall --show-only templates/heimdall-statefulset.yaml

# Test locally
helm upgrade --install heimdall ./heimdall -n heimdall-dev
```

### 3. Completing Work

```bash
# Mark task complete
bd close <task-id>

# Update session notes
# Create SESSION-XXX.md with work summary

# Commit changes
git status
git add <specific-files>
git commit -m "feat: descriptive message

Authored by: Aaron Lippold <lippold@gmail.com>"

# Sync beads
bd sync

# Push to remote
git push origin <branch-name>
```

## Troubleshooting Quick Reference

**Pod won't start**: `kubectl describe pod -n heimdall <pod-name>`
**Check logs**: `kubectl logs -n heimdall <pod-name> -f`
**Database issues**: `kubectl logs -n heimdall heimdall-postgresql-0`
**Template errors**: `helm template heimdall ./heimdall --debug`
**Beads issues**: `bd doctor --fix`

**Full troubleshooting guide**: See `docs/TROUBLESHOOTING.md`

## Testing Checklist

Before committing:
- [ ] `helm lint ./heimdall --strict` passes
- [ ] `helm template heimdall ./heimdall` renders without errors
- [ ] `kubectl apply --dry-run=client` validates successfully

Before PR:
- [ ] Chart installs to local cluster
- [ ] All pods reach Running state
- [ ] Database migrations execute
- [ ] Both embedded and external DB configs tested

**Full testing guide**: See `docs/TESTING.md`

## Important Reminders

- **Research first, borrow and adapt, create last** - Check Vulcan patterns before implementing
- **Everything configurable** - No hardcoded values in templates
- **Test incrementally** - Each change should be deployable
- **Document decisions** - Capture "why" not just "what"
- **Update Beads** - Keep task tracker current
- **Verify directory** - Always check `pwd` before git/helm commands

## Getting Help

**Issues**: https://github.com/mitre/heimdall-helm/issues
**Vulcan Reference**: `/Users/alippold/github/mitre/vulcan-helm/CLAUDE.md`
**Helm Docs**: https://helm.sh/docs/
**Bitnami Charts**: https://github.com/bitnami/charts
**Beads**: https://github.com/steveyegge/beads
