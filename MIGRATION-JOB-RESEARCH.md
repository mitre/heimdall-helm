# Database Migration Job Research - Heimdall Helm Chart

**Date**: 2025-12-30
**Context**: Phase 2 completion - Evaluating db-migrate-job.yaml necessity

## Executive Summary

**Key Finding**: The Heimdall `db-migrate-job.yaml` is **REDUNDANT** and should be **REMOVED**.

**Rationale**:
1. Heimdall's Docker entrypoint (`cmd.sh`) **already runs migrations on startup**
2. This creates a race condition where both job and app run migrations simultaneously
3. PVC persistence issues cause the job to fail across deployments
4. Industry best practice varies, but **when app runs migrations on startup, Helm hooks are unnecessary**

---

## Heimdall Application Behavior

### Container Startup Sequence (cmd.sh)

```bash
#!/bin/sh
set -e
yarn backend sequelize-cli db:migrate   # ← Migrations run here
yarn backend sequelize-cli db:seed:all  # ← Seeding run here
yarn backend start                      # ← Application starts
```

**Source**: [mitre/heimdall2/cmd.sh](https://github.com/mitre/heimdall2/blob/main/cmd.sh)

**Critical Point**: Every time a Heimdall container starts, it:
1. Runs database migrations
2. Seeds the database
3. Starts the application

This means migrations happen **automatically** without any Helm intervention.

---

## Vulcan Chart Comparison

### Vulcan Migration Strategy

Vulcan uses **BOTH** approaches:

1. **Separate Migration Job** (`vulcan/templates/db-migrate-job.yaml`)
   - Regular Job (NOT a Helm hook)
   - No `helm.sh/hook` annotations
   - Must be manually deployed: `kubectl apply -f vulcan/templates/db-migrate-job.yaml`

2. **Application Does NOT Run Migrations on Startup**
   - Dockerfile CMD: `["rails","server","-b","0.0.0.0"]`
   - No migration command in entrypoint
   - Rails app starts immediately without running `db:migrate`

**Key Difference**: Vulcan **separates** migration concerns from application startup.

---

## Industry Best Practices Research

### When to Use Helm Hook Migration Jobs

**Sources**: Stack Overflow, Helm docs, Atlas, ITNEXT, LinkedIn

#### ✅ **Use Helm Hooks When**:

1. **Application does NOT run migrations on startup**
   - Example: Vulcan, most Rails apps with separate migration step
   - Hook ensures migrations run before app deployment

2. **Zero-downtime deployments required**
   - Hook with `pre-upgrade` ensures migrations complete before new pods start
   - Prevents incompatible schema/code combinations

3. **Controlled migration timing needed**
   - Database changes must be ordered (e.g., backup → migrate → deploy)
   - Hook weights (`hook-weight`) control execution order

4. **CI/CD pipeline integration**
   - GitLab CI, GitHub Actions can trigger migrations via hooks
   - Separates migration approval from deployment approval

#### ❌ **DO NOT Use Helm Hooks When**:

1. **Application runs migrations on startup**
   - **Example: Heimdall** - migrations already in entrypoint
   - Creates race condition: job vs multiple pods all running migrations

2. **Sequelize/Prisma/Alembic handle idempotency**
   - ORMs track migration state, safe to run multiple times
   - Redundant job adds complexity without benefit

3. **Init containers used instead**
   - Some charts use init containers for migrations
   - Job + init container = double migration execution

---

## Recommended Approaches (Industry Standard)

### Approach 1: Application-Managed (Heimdall's Current Pattern)

**Pattern**: Migrations in application startup (Dockerfile CMD or entrypoint)

**Pros**:
- Simple - no extra Kubernetes objects
- Works identically in Docker Compose, Kubernetes, local development
- Sequelize handles idempotency (migration state tracking)
- Every pod self-heals database state on restart

**Cons**:
- Multiple replicas may compete to run migrations simultaneously
- No explicit migration approval step in CI/CD

**Best For**:
- Node.js apps with Sequelize/Prisma
- Python apps with Alembic/Django migrations
- Apps where migration idempotency is guaranteed

**Example Charts Using This**:
- Ghost (Node.js CMS)
- Directus (Node.js headless CMS)
- Strapi (Node.js CMS)

### Approach 2: Helm Hook Job (Vulcan's Pattern)

**Pattern**: Separate Job with `helm.sh/hook: pre-install,pre-upgrade`

**Pros**:
- Explicit migration step in deployment lifecycle
- Migrations complete before app starts
- Hook weights allow ordering (backup → migrate → deploy)
- Easy to troubleshoot (job logs separate from app logs)

**Cons**:
- Requires careful hook-weight management
- Service account must exist before hook runs
- Helm timeout can kill long-running migrations
- Adds complexity to chart

**Best For**:
- Rails apps (migrations separate from server start)
- Java/Spring apps (Flyway/Liquibase migrations)
- Apps with critical migration ordering requirements

**Example Charts Using This**:
- GitLab (Rails)
- Discourse (Rails)
- Mastodon (Rails)

### Approach 3: Init Container

**Pattern**: Init container runs migrations before main app container starts

**Pros**:
- Migrations guaranteed to complete before app starts
- Runs per-pod (each pod verifies migration state)
- No Helm-specific concepts (works with kubectl apply)

**Cons**:
- Multiple pods may run migrations simultaneously (if scaling > 1)
- Init containers share pod lifecycle (restart policy applies to both)
- Harder to troubleshoot (init container logs ephemeral)

**Best For**:
- Simple deployments (1 replica)
- Apps where migration race conditions are acceptable
- Charts targeting users unfamiliar with Helm hooks

**Example Charts Using This**:
- PostgreSQL initialization tasks
- Redis configuration setup
- Certificate generation

---

## Analysis: Heimdall's Current Implementation

### What We Have Now

```yaml
# heimdall/templates/db-migrate-job.yaml
annotations:
  "helm.sh/hook": post-install,post-upgrade
  "helm.sh/hook-weight": "-5"
  "helm.sh/hook-delete-policy": before-hook-creation
spec:
  backoffLimit: 3
  activeDeadlineSeconds: 300
  template:
    spec:
      containers:
        - name: db-migrate
          command:
            - yarn
            - backend
            - sequelize-cli
            - db:migrate
```

### Problems with This Approach

1. **Race Condition**:
   - Hook job runs: `yarn backend sequelize-cli db:migrate`
   - StatefulSet pod starts: `cmd.sh` runs `yarn backend sequelize-cli db:migrate`
   - Both execute migrations simultaneously

2. **Hook Timing Issue**:
   - `post-install,post-upgrade` means job runs AFTER app deployment
   - App pods may start before job completes
   - Defeats purpose of pre-migration validation

3. **PVC Persistence Problem**:
   - PostgreSQL PVC retains old password across uninstall/reinstall
   - Job uses new password from fresh secret
   - Authentication fails: `password authentication failed for user 'postgres'`

4. **Sequelize Already Handles This**:
   - Sequelize uses `SequelizeMeta` table to track applied migrations
   - Safe to run `db:migrate` multiple times
   - Only unapplied migrations execute

---

## Recommendation: Remove db-migrate-job.yaml

### Why Remove It

1. **Heimdall's design philosophy**: Migrations in application startup
   - `cmd.sh` is the canonical migration execution point
   - Removing job aligns Helm chart with upstream design

2. **Eliminates race condition**:
   - No competition between job and pods
   - Sequelize handles concurrent migration attempts gracefully

3. **Simpler chart maintenance**:
   - One less template to maintain
   - No hook ordering complexity
   - No ServiceAccount required for migration job

4. **Matches similar applications**:
   - Ghost, Directus, Strapi all run migrations on startup
   - No separate migration jobs in their Helm charts

### What We Keep

1. **Init container in StatefulSet** (already exists):
   ```yaml
   initContainers:
     - name: wait-for-postgres
       image: postgres:16-alpine
       command: ['sh', '-c', 'until pg_isready ...; do sleep 2; done']
   ```
   - Ensures PostgreSQL is ready before app starts
   - Prevents migration failures due to unavailable database

2. **Multi-pattern password injection** (already implemented):
   - Pattern 1: Embedded PostgreSQL → Bitnami secret
   - Pattern 2: External DB + existingSecret → User secret
   - Pattern 3: External DB no secret → Heimdall secrets

3. **Application's natural migration flow**:
   - Pod starts → wait-for-postgres init → cmd.sh runs migrations → app starts

---

## Alternative: If We Keep the Job

If there's a requirement to keep the migration job (e.g., regulatory compliance, audit trail), we should:

### Fix 1: Change to pre-install/pre-upgrade

```yaml
annotations:
  "helm.sh/hook": pre-install,pre-upgrade  # Changed from post-*
  "helm.sh/hook-weight": "-5"
```

**Rationale**: Migrations must complete before app pods start.

### Fix 2: Disable migrations in cmd.sh

Create custom entrypoint override:

```yaml
# values.yaml
heimdall:
  command: ["yarn", "backend", "start"]  # Skip db:migrate and db:seed
```

```yaml
# heimdall-statefulset.yaml
{{- if .Values.heimdall.command }}
command:
  {{- toYaml .Values.heimdall.command | nindent 12 }}
{{- end }}
```

**Rationale**: Only run migrations in one place (the job).

### Fix 3: Use hook-succeeded for app deployment

Make app deployment wait for migration job success (complex, not recommended).

---

## Vulcan Chart Patterns Review

### What Vulcan Does Well (Apply to Heimdall)

1. **Ingress Configuration** (`vulcan/templates/ingress.yaml`):
   - Supports multiple ingress classes (nginx, traefik, AWS ALB, GCP)
   - TLS configuration with cert-manager annotations
   - Path-based routing with configurable paths
   - Host-based routing with multiple hosts support

2. **TLS/SSL** (`vulcan/values.yaml`):
   ```yaml
   ingress:
     enabled: false
     className: "nginx"
     annotations:
       cert-manager.io/cluster-issuer: "letsencrypt-prod"
     hosts:
       - host: vulcan.example.com
         paths:
           - path: /
             pathType: Prefix
     tls:
       - secretName: vulcan-tls
         hosts:
           - vulcan.example.com
   ```

3. **High Availability**:
   - **PodDisruptionBudget**: Enabled by default (`minAvailable: 1`)
   - **HorizontalPodAutoscaler**: Disabled by default, easy to enable
   - **Resource limits**: Conservative defaults, production users override
   - **Anti-affinity**: Pod spreading across nodes

4. **Health Probes**:
   ```yaml
   livenessProbe:
     httpGet:
       path: /up
       port: http
     initialDelaySeconds: 30
     periodSeconds: 10
   readinessProbe:
     httpGet:
       path: /health_check
       port: http
     initialDelaySeconds: 15
     periodSeconds: 5
   ```

5. **ConfigMap + Secret Pattern**:
   - Non-sensitive config in ConfigMap
   - Sensitive data in Secret
   - `envFrom` for bulk loading
   - `env` for specific overrides (like DATABASE_PASSWORD)

---

## Implementation Plan

### Phase 1: Remove Migration Job

1. Delete `heimdall/templates/db-migrate-job.yaml`
2. Remove `dbMigrate` section from `values.yaml`
3. Remove `heimdall.dbMigrate.*` from `values.schema.json`
4. Update `CHANGELOG.md` with breaking change notice
5. Update documentation explaining migration strategy

### Phase 2: Document Migration Behavior

Create `docs/content/4.helm-chart/database-migrations.md`:

```markdown
# Database Migrations

Heimdall automatically runs Sequelize migrations on every pod startup via the
`cmd.sh` entrypoint script. No manual migration step is required.

## Migration Sequence

1. Pod starts
2. Init container waits for PostgreSQL readiness (`pg_isready`)
3. Container starts, executes `cmd.sh`:
   - `yarn backend sequelize-cli db:migrate`
   - `yarn backend sequelize-cli db:seed:all`
   - `yarn backend start`

## Idempotency

Sequelize tracks applied migrations in the `SequelizeMeta` table. Running
`db:migrate` multiple times is safe - only unapplied migrations execute.

## Multiple Replicas

When scaling to multiple replicas (HA mode), each pod runs migrations on startup.
Sequelize's migration locking prevents race conditions. The first pod to acquire
the lock runs pending migrations; other pods skip already-applied migrations.

## External Databases

When using external PostgreSQL (RDS, Cloud SQL), migrations still run on pod
startup. Ensure the Heimdall database user has DDL permissions (CREATE, ALTER, DROP).
```

### Phase 3: Apply Vulcan Patterns

- **Phase 3**: Health probes (startup/liveness/readiness) - already scoped
- **Phase 4**: Ingress (heimdall-helm-opy) - borrow from Vulcan
- **Phase 5**: TLS/SSL (heimdall-helm-xta) - borrow from Vulcan
- **Phase 6**: HA (heimdall-helm-jmn) - borrow from Vulcan

---

## References

### Research Sources

1. **Helm Official Documentation**:
   - [Chart Hooks](https://helm.sh/docs/topics/charts_hooks/)
   - [Best Practices](https://helm.sh/docs/chart_best_practices/)

2. **Industry Articles**:
   - [Database migrations on Kubernetes using Helm hooks (ITNEXT)](https://itnext.io/database-migrations-on-kubernetes-using-helm-hooks-fb80c0d97805)
   - [Deploying schema migrations to Kubernetes with Helm (Atlas)](https://atlasgo.io/guides/deploying/helm)
   - [Running database migrations when deploying to Kubernetes](https://andrewlock.net/deploying-asp-net-core-applications-to-kubernetes-part-7-running-database-migrations/)

3. **Stack Overflow Discussions**:
   - [Database migrations in Helm charts using pre-install, pre-upgrade hook](https://stackoverflow.com/questions/79173735/)
   - [InitContainer or Helm Hook Database Migrations Rollback](https://stackoverflow.com/questions/73063977/)
   - [Managing DB migrations on Kubernetes cluster](https://stackoverflow.com/questions/50218376/)

4. **Production Charts**:
   - [Bitnami Charts](https://github.com/bitnami/charts) - Industry standard patterns
   - [GitLab Helm Chart](https://gitlab.com/gitlab-org/charts/gitlab) - Complex migration strategy
   - [Vulcan Helm Chart](https://github.com/mitre/vulcan-helm) - MITRE reference implementation

### Application Sources

- [Heimdall2 Source Code](https://github.com/mitre/heimdall2)
  - `cmd.sh` - Entrypoint with migrations
  - `Dockerfile` - Container build
  - `apps/backend/package.json` - Sequelize CLI scripts

- [Vulcan Source Code](https://github.com/mitre/vulcan)
  - `Dockerfile` - Rails server only (no migrations in CMD)
  - Migrations run separately via db:migrate job

---

## Conclusion

**Remove `db-migrate-job.yaml`** from the Heimdall Helm chart.

**Reasoning**:
1. Heimdall's architecture runs migrations on startup (by design)
2. Separate job creates race condition and complexity
3. Sequelize handles idempotency - safe for multiple pods
4. Aligns chart with application's intended behavior
5. Simplifies chart maintenance and troubleshooting

**Next Steps**:
1. Delete migration job template and related values
2. Document Heimdall's migration strategy
3. Apply Vulcan's ingress/TLS/HA patterns (Phases 3-6)
4. Test with multiple replicas to verify migration behavior

**Impact**:
- **Breaking Change**: Users relying on migration job must understand new behavior
- **Migration Path**: No action required - migrations still run (via application)
- **Documentation**: Critical to explain new migration strategy clearly
