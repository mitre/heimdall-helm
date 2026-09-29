#!/usr/bin/env bash
# External PostgreSQL supplied by a GitHub Actions service container.
source "$(dirname "$0")/lib.sh"
NS=lifecycle-service-pg
EXTERNAL_POSTGRES_HOST="${EXTERNAL_POSTGRES_HOST:-}"
EXTERNAL_POSTGRES_PORT="${EXTERNAL_POSTGRES_PORT:-5432}"
EXTERNAL_POSTGRES_PASSWORD="${EXTERNAL_POSTGRES_PASSWORD:-lifecycle-postgres-password}"
trap 'cleanup_ns "$NS"' EXIT

[[ -n "$EXTERNAL_POSTGRES_HOST" ]] \
  || fail "EXTERNAL_POSTGRES_HOST is required; see README.md for local and CI examples"

log "Scenario 3: external PostgreSQL at $EXTERNAL_POSTGRES_HOST:$EXTERNAL_POSTGRES_PORT"
cat > "$GEN/external-postgres.yaml" <<VALS
jwtSecret: "$(openssl rand -hex 64)"
apiKeySecret: "$(openssl rand -hex 33)"
adminPassword: "Lifecycle-Test-Password-1!"
externalUrl: "http://localhost:3000"
databaseHost: "$EXTERNAL_POSTGRES_HOST"
databasePort: $EXTERNAL_POSTGRES_PORT
databaseName: heimdall
databaseUsername: postgres
databasePassword: "$EXTERNAL_POSTGRES_PASSWORD"
postgresql:
  enabled: false
heimdall:
  ingress:
    enabled: false
VALS

helm install "$RELEASE" "$CHART" -n "$NS" --create-namespace -f "$GEN/external-postgres.yaml"
wait_ready "$NS"
check_http "$NS" 18083

actual="$(kubectl get statefulset "$RELEASE" -n "$NS" \
  -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="DATABASE_HOST")].value}')"
[[ "$actual" == "$EXTERNAL_POSTGRES_HOST" ]] \
  || fail "chart configured database host '$actual', expected '$EXTERNAL_POSTGRES_HOST'"
pass "chart works with the GitHub Actions PostgreSQL service"
