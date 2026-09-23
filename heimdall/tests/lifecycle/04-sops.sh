#!/usr/bin/env bash
# SOPS encrypts the data used to create an external Kubernetes Secret.
source "$(dirname "$0")/lib.sh"
require sops age-keygen
NS=lifecycle-sops
SECRET_NAME=heimdall-sops-secrets
trap 'cleanup_ns "$NS"' EXIT

log "Scenario 4: SOPS-managed external Secret"
gen_min_values
rm -f "$GEN/sops-key.txt"
age-keygen -o "$GEN/sops-key.txt" 2>/dev/null
public_key="$(awk '/public key/ {print $4}' "$GEN/sops-key.txt")"

cat > "$GEN/sops-plain.env" <<ENV
JWT_SECRET=$(openssl rand -hex 64)
API_KEY_SECRET=$(openssl rand -hex 33)
ADMIN_PASSWORD=Lifecycle-Test-Password-1!
ENV
sops --encrypt --age "$public_key" --input-type dotenv --output-type dotenv \
  "$GEN/sops-plain.env" > "$GEN/sops-encrypted.env"
grep -q 'ENC\[AES256_GCM' "$GEN/sops-encrypted.env" || fail "SOPS output is not encrypted"
pass "secret values were encrypted with SOPS and age"

kubectl create namespace "$NS"
SOPS_AGE_KEY_FILE="$GEN/sops-key.txt" sops --decrypt --input-type dotenv --output-type dotenv \
  "$GEN/sops-encrypted.env" > "$GEN/sops-decrypted.env"
kubectl create secret generic "$SECRET_NAME" -n "$NS" --from-env-file="$GEN/sops-decrypted.env"

cat > "$GEN/sops-values.yaml" <<VALS
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

rendered="$(helm template "$RELEASE" "$CHART" -n "$NS" -f "$GEN/sops-values.yaml")"
! grep -q '^  name: heimdall-secrets$' <<<"$rendered" \
  || fail "chart rendered its own Heimdall Secret while existingSecret was set"

helm install "$RELEASE" "$CHART" -n "$NS" -f "$GEN/sops-values.yaml"
wait_ready "$NS"
actual="$(kubectl get statefulset "$RELEASE" -n "$NS" \
  -o jsonpath='{.spec.template.spec.containers[0].envFrom[1].secretRef.name}')"
[[ "$actual" == "$SECRET_NAME" ]] || fail "StatefulSet references '$actual', expected '$SECRET_NAME'"
rm -f "$GEN/sops-decrypted.env"
pass "chart consumes the SOPS-managed external Secret"
