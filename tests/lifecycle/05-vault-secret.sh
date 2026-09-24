#!/usr/bin/env bash
# Validate the Kubernetes Secret contract a Vault integration must satisfy.
source "$(dirname "$0")/lib.sh"
NS=lifecycle-vault
SECRET_NAME="$RELEASE"
trap 'cleanup_ns "$NS"' EXIT

log "Scenario 5: Vault-compatible external Secret contract"
kubectl create namespace "$NS"
kubectl create secret generic "$SECRET_NAME" -n "$NS" \
  --from-literal=databaseUsername=postgres \
  --from-literal=databasePassword="$(openssl rand -hex 33)" \
  --from-literal=jwtSecret="$(openssl rand -hex 64)" \
  --from-literal=apiKeySecret="$(openssl rand -hex 33)" \
  --from-literal=adminPassword='Lifecycle-Test-Password-1!'

cat > "$GEN/vault-values.yaml" <<VALS
externalUrl: "http://localhost:3000"
sops:
  enabled: true
  secrets:
    - DATABASE_USERNAME
    - DATABASE_PASSWORD
    - JWT_SECRET
    - API_KEY_SECRET
    - ADMIN_PASSWORD
heimdall:
  ingress:
    enabled: false
VALS

rendered="$(helm template "$RELEASE" "$CHART" -n "$NS" -f "$GEN/vault-values.yaml")"
! grep -q '^kind: Secret$' <<<"$rendered" \
  || fail "chart rendered a competing Secret while using the external Secret contract"

helm install "$RELEASE" "$CHART" -n "$NS" -f "$GEN/vault-values.yaml"
wait_ready "$NS"
env_refs="$(kubectl get statefulset "$RELEASE" -n "$NS" \
  -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}{"="}{.valueFrom.secretKeyRef.name}{"\n"}{end}')"
for variable in DATABASE_USERNAME DATABASE_PASSWORD JWT_SECRET API_KEY_SECRET ADMIN_PASSWORD; do
  grep -qx "$variable=$SECRET_NAME" <<<"$env_refs" \
    || fail "$variable is not wired to Secret '$SECRET_NAME'"
done
check_http "$NS" 18085
pass "Vault-managed Secret contract works"
