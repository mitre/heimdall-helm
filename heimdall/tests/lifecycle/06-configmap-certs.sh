#!/usr/bin/env bash
# Baseline ConfigMap plus custom CA certificate bundle.
source "$(dirname "$0")/lib.sh"
NS=lifecycle-configmap
trap 'cleanup_ns "$NS"' EXIT

log "Scenario 6: baseline ConfigMap and custom CA bundle"
gen_min_values
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$GEN/ca-key.pem" -out "$GEN/ca.pem" \
  -subj "/CN=lifecycle-test-ca" -days 2 2>/dev/null

cat > "$GEN/configmap-values.yaml" <<VALS
heimdall:
  secretsFiles: []
  secrets:
    JWT_SECRET: "$(openssl rand -hex 64)"
    API_KEY_SECRET: "$(openssl rand -hex 33)"
    ADMIN_PASSWORD: "Lifecycle-Test-Password-1!"
  config:
    EXTERNAL_URL: "http://localhost:3000"
    CLASSIFICATION_BANNER_TEXT: "LIFECYCLE TEST"
postgresql:
  auth:
    postgresPassword: "$DB_PASSWORD"
    password: "$DB_PASSWORD"
  primary:
    persistence:
      enabled: false
extraCertificates:
  enabled: true
  certificates:
    lifecycle-ca.pem: |
$(sed 's/^/      /' "$GEN/ca.pem")
VALS

helm install "$RELEASE" "$CHART" -n "$NS" --create-namespace -f "$GEN/configmap-values.yaml"
wait_ready "$NS"

[[ "$(kubectl get configmap "$RELEASE-config" -n "$NS" \
  -o jsonpath='{.data.CLASSIFICATION_BANNER_TEXT}')" == 'LIFECYCLE TEST' ]] \
  || fail "baseline configuration value is missing"
kubectl get configmap "$RELEASE-ca-certs" -n "$NS" >/dev/null \
  || fail "custom CA ConfigMap is missing"

env_output="$(kubectl exec -n "$NS" "$RELEASE-0" -c heimdall-front -- env)"
grep -qx 'NODE_EXTRA_CA_CERTS=/usr/local/share/ca-certificates/ca-bundle.pem' <<<"$env_output" \
  || fail "NODE_EXTRA_CA_CERTS is not set"
kubectl exec -n "$NS" "$RELEASE-0" -c heimdall-front -- \
  grep -q 'BEGIN CERTIFICATE' /usr/local/share/ca-certificates/ca-bundle.pem \
  || fail "generated CA bundle does not contain a certificate"
pass "baseline ConfigMap and custom CA bundle work"
