#!/usr/bin/env bash
# Scenario 4: secrets managed externally with SOPS (age key), consumed via sops.enabled=true.
source "$(dirname "$0")/lib.sh"
require sops age-keygen
NS=t4-sops
trap 'cleanup_ns $NS' EXIT

log "Scenario 4: SOPS-managed secrets"
gen_min_values
cd "$GEN"
rm -f sops-key.txt
age-keygen -o sops-key.txt 2>/dev/null
PUB="$(grep 'public key' sops-key.txt | awk '{print $4}')"

# Key names are camelCase because that is what the chart's secretKeyRef entries use.
cat > sops-plain.env <<ENV
databaseUsername=postgres
databasePassword=$(openssl rand -hex 33)
jwtSecret=$(openssl rand -hex 64)
apiKeySecret=$(openssl rand -hex 33)
ENV
sops --encrypt --age "$PUB" --input-type dotenv --output-type dotenv sops-plain.env > sops-enc.env
grep -q 'ENC\[AES256_GCM' sops-enc.env || fail "file was not encrypted"
! grep -q "$(grep databasePassword sops-plain.env | cut -d= -f2)" sops-enc.env || fail "plaintext leaked into encrypted file"
pass "secrets encrypted"

# Stand-in for the in-cluster SOPS generator: decrypt and create the Secret the chart expects.
kubectl create ns "$NS"
SOPS_AGE_KEY_FILE=sops-key.txt sops --decrypt --input-type dotenv --output-type dotenv sops-enc.env > sops-dec.env
kubectl create secret generic "$RELEASE" -n "$NS" --from-env-file=sops-dec.env
rm -f sops-dec.env

cat > sops-vals.yaml <<VALS
externalUrl: http://localhost:3000
sops:
  enabled: true
  secrets: [DATABASE_USERNAME, DATABASE_PASSWORD, JWT_SECRET, API_KEY_SECRET]
VALS

[[ -z "$(helm template "$RELEASE" "$CHART" -f sops-vals.yaml | grep '^kind: Secret' || true)" ]] \
  || fail "chart rendered its own Secret in SOPS mode"
pass "chart renders no Secret in SOPS mode"

helm install "$RELEASE" "$CHART" -n "$NS" -f sops-vals.yaml
wait_ready "$NS"

envmap="$(kubectl get pod "$RELEASE-0" -n "$NS" -o jsonpath='{range .spec.containers[0].env[*]}{.name}{"="}{.valueFrom.secretKeyRef.name}{"\n"}{end}')"
for v in DATABASE_USERNAME DATABASE_PASSWORD JWT_SECRET API_KEY_SECRET; do
  grep -qx "$v=$RELEASE" <<<"$envmap" || fail "$v is not wired to Secret '$RELEASE'"
done
pass "env vars resolve from the external Secret"

# Known issue (opt-in): the repo's kustomize generator files are misnamed.
if [[ "${RUN_KNOWN_ISSUES:-0}" == 1 ]]; then
  require kustomize
  if kustomize build --enable-alpha-plugins "$REPO_ROOT/sops" >/dev/null 2>&1; then
    fail "kustomize build of sops/ now succeeds (known issue may be fixed; update this test)"
  fi
  pass "sops/ kustomize build fails as documented"
fi
