#!/usr/bin/env bash
# Scenario 3: postgres image pulled from GitHub Container Registry.
# Override the image with GHCR_PG_IMAGE / GHCR_PG_TAG.
source "$(dirname "$0")/lib.sh"
IMG="${GHCR_PG_IMAGE:-ghcr.io/immich-app/postgres}"
TAG="${GHCR_PG_TAG:-17-vectorchord0.4.3}"
NS=t3-ghcr-pg
trap 'cleanup_ns $NS; cleanup_ns t3a-cnpg' EXIT

log "Scenario 3: postgres from GHCR ($IMG:$TAG)"
gen_min_values
helm install "$RELEASE" "$CHART" -n "$NS" --create-namespace -f "$GEN/min.yaml" \
  --set postgresql.image.repository="$IMG" --set postgresql.image.tag="$TAG"
wait_ready "$NS"
actual="$(kubectl get pod "$RELEASE-postgresql-0" -n "$NS" -o jsonpath='{.spec.containers[0].image}')"
[[ "$actual" == "$IMG:$TAG" ]] || fail "postgres pod uses $actual"
check_http "$NS"
pass "GHCR postgres image works"

# Known limitation (opt-in): the CloudNativePG operand image has no server entrypoint.
if [[ "${RUN_KNOWN_ISSUES:-0}" == 1 ]]; then
  log "Known issue: CNPG image should NOT become Ready"
  helm install "$RELEASE" "$CHART" -n t3a-cnpg --create-namespace -f "$GEN/min.yaml" \
    --set postgresql.image.repository=ghcr.io/cloudnative-pg/postgresql --set postgresql.image.tag=17
  sleep 60
  ready="$(kubectl get pod "$RELEASE-postgresql-0" -n t3a-cnpg -o jsonpath='{.status.containerStatuses[0].ready}')"
  [[ "$ready" != true ]] || fail "CNPG image unexpectedly became Ready (known issue may be fixed; update this test)"
  pass "CNPG image fails as documented"
fi
