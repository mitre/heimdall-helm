#!/usr/bin/env bash
# Scenario 5: baseline ConfigMap config (custom CA certs), both injection approaches.
source "$(dirname "$0")/lib.sh"
NS=t5-certs
trap 'cleanup_ns $NS' EXIT

log "Scenario 5: certs ConfigMap"
gen_min_values
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$GEN/ca-key.pem" -out "$GEN/ca.pem" \
  -subj "/CN=test-ca" -days 2 2>/dev/null
{
  cat "$GEN/min.yaml"
  printf 'certs:\n  enabled: true\n  name: heimdall-cacerts\n  certificates:\n    - filename: certs.pem\n      contents: |\n'
  sed 's/^/        /' "$GEN/ca.pem"     # indent to nest under "contents: |"
} > "$GEN/certs-vals.yaml"

helm install "$RELEASE" "$CHART" -n "$NS" --create-namespace -f "$GEN/certs-vals.yaml"
wait_ready "$NS"
kubectl get cm heimdall-cacerts -n "$NS" >/dev/null || fail "ConfigMap heimdall-cacerts missing"
env_out="$(kubectl exec -n "$NS" "$RELEASE-0" -- env)"
grep -qx 'NODE_EXTRA_CA_CERTS=/home/node/certs/certs.pem' <<<"$env_out" || fail "NODE_EXTRA_CA_CERTS not set"
grep -qx 'SSL_CERT_FILE=/home/node/certs/certs.pem' <<<"$env_out" || fail "SSL_CERT_FILE not set"
kubectl exec -n "$NS" "$RELEASE-0" -- cat /home/node/certs/certs.pem | diff - "$GEN/ca.pem" >/dev/null \
  || fail "mounted cert differs from supplied cert"
pass "single-file approach: cert mounted and env vars set"

log "System-certs approach (init container runs update-ca-trust)"
count_certs() {
  kubectl exec -n "$NS" "$RELEASE-0" -c heimdall-front -- \
    awk '/BEGIN CERT/{n++} END{print n}' /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem
}
helm upgrade "$RELEASE" "$CHART" -n "$NS" -f "$GEN/certs-vals.yaml" --set certs.systemCertsApproach.enabled=true
kubectl rollout status statefulset/"$RELEASE" -n "$NS" --timeout="$WAIT_TIMEOUT"
wait_ready "$NS"
[[ "$(kubectl get pod "$RELEASE-0" -n "$NS" -o jsonpath='{.spec.initContainers[0].name}')" == setup-certs ]] \
  || fail "setup-certs init container missing"
n="$(count_certs)"
# The stock bundle has ~146 certs; ours makes it larger. Compare against a no-injection baseline for an exact check.
(( n > 146 )) || fail "trust bundle has $n certs (expected > 146)"
pass "system-certs approach: bundle has $n certs (custom CA injected)"
