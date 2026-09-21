#!/usr/bin/env bash
# Shared helpers for the chart test scenarios. Source this file; do not run it.
#
# Assumes kubectl's current context points at a disposable cluster (e.g. kind).
# All generated files (keys, certs, secrets) live in tests/.generated, which is gitignored.

set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TESTS_DIR/.." && pwd)"
CHART="$REPO_ROOT/heimdall2"
GEN="$TESTS_DIR/.generated"
RELEASE="heimdall"                 # SOPS mode expects the Secret to be named after this release
WAIT_TIMEOUT="${WAIT_TIMEOUT:-300s}"
STORAGE_CLASS="${STORAGE_CLASS:-standard}"   # kind's default; override for other clusters

mkdir -p "$GEN"

log()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
pass() { printf '\033[32mPASS\033[0m %s\n' "$*"; }
fail() { printf '\033[31mFAIL\033[0m %s\n' "$*" >&2; exit 1; }

require() {
  for tool in "$@"; do
    command -v "$tool" >/dev/null || fail "missing required tool: $tool"
  done
}

# Refuse to run against anything that isn't obviously disposable, unless overridden.
check_context() {
  local ctx
  ctx="$(kubectl config current-context)"
  log "kubectl context: $ctx"
  if [[ "$ctx" != kind-* && "$ctx" != k3d-* && "${ALLOW_ANY_CONTEXT:-0}" != 1 ]]; then
    fail "context '$ctx' is not kind/k3d. Set ALLOW_ANY_CONTEXT=1 to run anyway."
  fi
  # A freshly created cluster reports NotReady for a few seconds; pods cannot schedule until then.
  kubectl wait --for=condition=Ready node --all --timeout=120s || fail "cluster nodes not Ready"
}

# Writes the bare-minimum values file (fresh random secrets each run).
gen_min_values() {
  cat > "$GEN/min.yaml" <<VALS
jwtSecret: $(openssl rand -hex 64)
databasePassword: $(openssl rand -hex 33)
apiKeySecret: $(openssl rand -hex 33)
externalUrl: http://localhost:3000
VALS
}

# Removes a scenario's release and namespace. Safe to call repeatedly.
cleanup_ns() {
  local ns="$1"
  helm uninstall "$RELEASE" -n "$ns" >/dev/null 2>&1 || true
  kubectl delete ns "$ns" --wait=false >/dev/null 2>&1 || true
}

# Waits until every pod in the namespace is Ready (Heimdall's probe delays ~80s).
wait_ready() {
  local ns="$1"
  kubectl wait --for=condition=ready pod --all -n "$ns" --timeout="$WAIT_TIMEOUT" \
    || { kubectl get pods -n "$ns"; kubectl describe pods -n "$ns" | tail -40; fail "pods in $ns not ready"; }
}

# Confirms the app answers over HTTP through a port-forward.
check_http() {
  local ns="$1" port="${2:-18081}" code=000
  kubectl port-forward -n "$ns" "svc/$RELEASE" "$port:3000" >/dev/null 2>&1 &
  local pf=$!
  for _ in $(seq 1 15); do
    code="$(curl -s -o /dev/null -w '%{http_code}' "localhost:$port/" || true)"
    [[ "$code" == 200 ]] && break
    sleep 2
  done
  kill "$pf" 2>/dev/null || true
  [[ "$code" == 200 ]] || fail "GET / returned $code (expected 200)"
  pass "app serves HTTP 200"
}

psql_in() {  # psql_in <ns> <sql>
  kubectl exec -n "$1" "$RELEASE-postgresql-0" -- psql -U postgres -d heimdall-database -tA -c "$2"
}
