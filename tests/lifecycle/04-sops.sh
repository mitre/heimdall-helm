#!/usr/bin/env bash
# SOPS encrypts the values used to create the external Secret expected by the chart.
source "$(dirname "$0")/lib.sh"
require sops age-keygen
NS=lifecycle-sops
SECRET_NAME="$RELEASE"
trap 'cleanup_ns "$NS"' EXIT

log "Scenario 4: SOPS-managed external Secret"
rm -f "$GEN/sops-key.txt"
age-keygen -o "$GEN/sops-key.txt" 2>/dev/null
public_key="$(awk '/public key/ {print $4}' "$GEN/sops-key.txt")"

cat > "$GEN/sops-plain.env" <<ENV
databaseUsername=postgres
databasePassword=$(openssl rand -hex 33)
jwtSecret=$(openssl rand -hex 64)
apiKeySecret=$(openssl rand -hex 33)
adminPassword=Lifecycle-Test-Password-1!
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

rendered="$(helm template "$RELEASE" "$CHART" -n "$NS" -f "$GEN/sops-values.yaml")"
! grep -q '^kind: Secret$' <<<"$rendered" \
  || fail "chart rendered its own Secret while SOPS mode was enabled"

helm install "$RELEASE" "$CHART" -n "$NS" -f "$GEN/sops-values.yaml"
wait_ready "$NS"
env_refs="$(kubectl get statefulset "$RELEASE" -n "$NS" \
  -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name}{"="}{.valueFrom.secretKeyRef.name}{"\n"}{end}')"
for variable in DATABASE_USERNAME DATABASE_PASSWORD JWT_SECRET API_KEY_SECRET ADMIN_PASSWORD; do
  grep -qx "$variable=$SECRET_NAME" <<<"$env_refs" \
    || fail "$variable is not wired to Secret '$SECRET_NAME'"
done
rm -f "$GEN/sops-decrypted.env"
pass "chart consumes the SOPS-managed external Secret"
