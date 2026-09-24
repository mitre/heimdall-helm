#!/usr/bin/env bash
# Baseline certificate ConfigMap using direct and system trust-store injection.
source "$(dirname "$0")/lib.sh"
NS=lifecycle-configmap
CERTS_IMAGE="${CERTS_IMAGE:-registry.access.redhat.com/ubi8/ubi}"
CERTS_IMAGE_TAG="${CERTS_IMAGE_TAG:-latest}"
trap 'cleanup_ns "$NS"' EXIT

log "Scenario 6: certificate ConfigMap"
gen_min_values
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$GEN/ca-key.pem" -out "$GEN/ca.pem" \
  -subj "/CN=lifecycle-test-ca" -days 2 2>/dev/null
{
  cat "$GEN/min.yaml"
  printf 'certs:\n  enabled: true\n  name: heimdall-cacerts\n  certificates:\n    - filename: lifecycle-ca.pem\n      contents: |\n'
  sed 's/^/        /' "$GEN/ca.pem"
} > "$GEN/configmap-values.yaml"

helm install "$RELEASE" "$CHART" -n "$NS" --create-namespace -f "$GEN/configmap-values.yaml"
wait_ready "$NS"
kubectl get configmap heimdall-cacerts -n "$NS" >/dev/null \
  || fail "certificate ConfigMap is missing"
env_output="$(kubectl exec -n "$NS" "$RELEASE-0" -c heimdall-front -- env)"
grep -qx 'NODE_EXTRA_CA_CERTS=/home/node/certs/lifecycle-ca.pem' <<<"$env_output" \
  || fail "NODE_EXTRA_CA_CERTS does not use the configured filename"
grep -qx 'SSL_CERT_FILE=/home/node/certs/lifecycle-ca.pem' <<<"$env_output" \
  || fail "SSL_CERT_FILE does not use the configured filename"
kubectl exec -n "$NS" "$RELEASE-0" -c heimdall-front -- \
  cat /home/node/certs/lifecycle-ca.pem | diff - "$GEN/ca.pem" >/dev/null \
  || fail "mounted certificate differs from the supplied certificate"
pass "direct certificate injection works"

log "System trust-store approach with $CERTS_IMAGE:$CERTS_IMAGE_TAG"
helm upgrade "$RELEASE" "$CHART" -n "$NS" -f "$GEN/configmap-values.yaml" \
  --set certs.systemCertsApproach.enabled=true \
  --set certs.systemCertsApproach.image.repository="$CERTS_IMAGE" \
  --set-string certs.systemCertsApproach.image.tag="$CERTS_IMAGE_TAG"
kubectl rollout status statefulset/"$RELEASE" -n "$NS" --timeout="$WAIT_TIMEOUT"
wait_ready "$NS"
[[ "$(kubectl get pod "$RELEASE-0" -n "$NS" -o jsonpath='{.spec.initContainers[0].name}')" \
    == setup-certs ]] || fail "setup-certs init container is missing"
certificate_count="$(kubectl exec -n "$NS" "$RELEASE-0" -c heimdall-front -- \
  awk '/BEGIN CERT/{count++} END{print count}' /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem)"
(( certificate_count > 146 )) \
  || fail "trust bundle has $certificate_count certificates (expected more than 146)"
pass "system trust store contains the injected certificate"
