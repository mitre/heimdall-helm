#!/usr/bin/env bash
# Scenario 2: in-cluster postgres with a persistent volume; data must survive a pod restart.
source "$(dirname "$0")/lib.sh"
NS=t2-local-pg
trap 'cleanup_ns $NS' EXIT

log "Scenario 2: local postgres with persistence"
gen_min_values
helm install "$RELEASE" "$CHART" -n "$NS" --create-namespace -f "$GEN/min.yaml" \
  --set postgresql.persistence.enabled=true \
  --set postgresql.persistence.storageClassName="$STORAGE_CLASS"
wait_ready "$NS"

phase="$(kubectl get pvc "$RELEASE-db-data" -n "$NS" -o jsonpath='{.status.phase}')"
[[ "$phase" == Bound ]] || fail "PVC phase is '$phase' (expected Bound)"
pass "PVC bound"

psql_in "$NS" "create table persist_check(x int); insert into persist_check values (42);" >/dev/null
kubectl delete pod -n "$NS" "$RELEASE-postgresql-0"
kubectl wait --for=condition=ready pod "$RELEASE-postgresql-0" -n "$NS" --timeout="$WAIT_TIMEOUT"
[[ "$(psql_in "$NS" 'select x from persist_check;')" == 42 ]] || fail "data lost after postgres restart"
pass "data survived postgres restart"

[[ "$(psql_in "$NS" "select count(*) from information_schema.tables where table_name='Users';")" == 1 ]] \
  || fail "Heimdall schema not migrated"
pass "Heimdall schema migrated"
