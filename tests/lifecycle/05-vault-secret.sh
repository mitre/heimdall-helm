#!/usr/bin/env bash
# Validate the Secret contract used by Vault/External Secrets integrations.
source "$(dirname "$0")/lib.sh"
NS=lifecycle-vault
SECRET_NAME=heimdall-vault-secrets
trap 'cleanup_ns "$NS"' EXIT

log "Scenario 5: Vault-compatible existingSecret contract"
gen_min_values
kubectl create namespace "$NS"
kubectl create secret generic "$SECRET_NAME" -n "$NS" \
  --from-literal=JWT_SECRET="$(openssl rand -hex 64)" \
  --from-literal=API_KEY_SECRET="$(openssl rand -hex 33)" \
  --from-literal=ADMIN_PASSWORD='Lifecycle-Test-Password-1!'

cat > "$GEN/vault-values.yaml" <<VALS
heimdall:
  existingSecret: "$SECRET_NAME"
  secretsFiles: []
  config:
    EXTERNAL_URL: "http://localhost:3000"
postgresql:
  auth:
    postgresPassword: "$DB_PASSWORD"
    password: "$DB_PASSWORD"
  primary:
    persistence:
      enabled: false
VALS

helm install "$RELEASE" "$CHART" -n "$NS" -f "$GEN/vault-values.yaml"
wait_ready "$NS"
actual="$(kubectl get statefulset "$RELEASE" -n "$NS" \
  -o jsonpath='{.spec.template.spec.containers[0].envFrom[1].secretRef.name}')"
[[ "$actual" == "$SECRET_NAME" ]] || fail "StatefulSet references '$actual', expected '$SECRET_NAME'"
[[ -z "$(kubectl get secret "$RELEASE-secrets" -n "$NS" --ignore-not-found -o name)" ]] \
  || fail "chart created a competing Secret while existingSecret was set"
check_http "$NS" 18085
pass "Vault-managed Secret contract works"
