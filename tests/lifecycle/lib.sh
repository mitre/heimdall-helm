#!/usr/bin/env bash
# Shared helpers for lifecycle tests. Source this file; do not run it directly.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/../.." && pwd)"
CHART="$REPO_ROOT/heimdall2"
GEN="$TESTS_DIR/.generated"
RELEASE="heimdall"
WAIT_TIMEOUT="${WAIT_TIMEOUT:-600s}"
STORAGE_CLASS="${STORAGE_CLASS:-standard}"

mkdir -p "$GEN"

log()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
pass() { printf '\033[32mPASS\033[0m %s\n' "$*"; }
fail() { printf '\033[31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }

require() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null || fail "missing required tool: $tool"
  done
}

check_context() {
  local context
  context="$(kubectl config current-context)"
  log "kubectl context: $context"
  if [[ "$context" != kind-* && "$context" != k3d-* && "${ALLOW_ANY_CONTEXT:-0}" != 1 ]]; then
    fail "context '$context' is not kind/k3d; set ALLOW_ANY_CONTEXT=1 to override"
  fi
  kubectl wait --for=condition=Ready node --all --timeout=120s \
    || fail "cluster nodes are not Ready"
}

gen_min_values() {
  DB_PASSWORD="$(openssl rand -hex 33)"
  export DB_PASSWORD
  cat > "$GEN/min.yaml" <<VALS
jwtSecret: "$(openssl rand -hex 64)"
databasePassword: "$DB_PASSWORD"
apiKeySecret: "$(openssl rand -hex 33)"
adminPassword: "Lifecycle-Test-Password-1!"
externalUrl: "http://localhost:3000"
postgresql:
  persistence:
    enabled: false
heimdall:
  ingress:
    enabled: false
VALS
}

cleanup_ns() {
  local namespace="$1"
  helm uninstall "$RELEASE" -n "$namespace" >/dev/null 2>&1 || true
  kubectl delete namespace "$namespace" --wait=false >/dev/null 2>&1 || true
}

wait_ready() {
  local namespace="$1"
  kubectl wait --for=condition=ready pod --all -n "$namespace" --timeout="$WAIT_TIMEOUT" \
    || {
      kubectl get pods -n "$namespace" -o wide || true
      kubectl describe pods -n "$namespace" | tail -80 || true
      fail "pods in $namespace did not become Ready"
    }
}

check_http() {
  local namespace="$1" port="${2:-18081}" code=000 port_forward_pid
  kubectl port-forward -n "$namespace" "service/$RELEASE" "$port:3000" >/dev/null 2>&1 &
  port_forward_pid=$!
  for _ in $(seq 1 30); do
    code="$(curl --silent --output /dev/null --write-out '%{http_code}' "http://localhost:$port/" || true)"
    [[ "$code" == 200 ]] && break
    sleep 2
  done
  kill "$port_forward_pid" >/dev/null 2>&1 || true
  wait "$port_forward_pid" 2>/dev/null || true
  [[ "$code" == 200 ]] || fail "GET / returned $code (expected 200)"
  pass "application serves HTTP 200"
}

psql_in() {
  local namespace="$1" sql="$2"
  kubectl exec -n "$namespace" "$RELEASE-postgresql-0" -- \
    env PGPASSWORD="$DB_PASSWORD" psql -U postgres -d heimdall-database -tA -c "$sql"
}
