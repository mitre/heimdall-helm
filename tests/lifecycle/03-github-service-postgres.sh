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
gen_min_values
kubectl create namespace "$NS"
kubectl create secret generic external-postgres -n "$NS" \
  --from-literal=password="$EXTERNAL_POSTGRES_PASSWORD"

cat > "$GEN/external-postgres.yaml" <<VALS
heimdall:
  secretsFiles: []
  secrets:
    JWT_SECRET: "$(openssl rand -hex 64)"
    API_KEY_SECRET: "$(openssl rand -hex 33)"
    ADMIN_PASSWORD: "Lifecycle-Test-Password-1!"
  config:
    EXTERNAL_URL: "http://localhost:3000"
postgresql:
  enabled: false
externalDatabase:
  host: "$EXTERNAL_POSTGRES_HOST"
  port: $EXTERNAL_POSTGRES_PORT
  database: heimdall
  username: postgres
  existingSecret: external-postgres
  existingSecretPasswordKey: password
VALS

helm install "$RELEASE" "$CHART" -n "$NS" -f "$GEN/external-postgres.yaml"
wait_ready "$NS"
check_http "$NS" 18083

[[ "$(kubectl get configmap "$RELEASE-config" -n "$NS" -o jsonpath='{.data.DATABASE_HOST}')" \
    == "$EXTERNAL_POSTGRES_HOST" ]] || fail "chart did not configure the external database host"
pass "chart works with the GitHub Actions PostgreSQL service"
