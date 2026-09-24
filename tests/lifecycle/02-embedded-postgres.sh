#!/usr/bin/env bash
# Embedded PostgreSQL: PVC binds and data survives a pod restart.
source "$(dirname "$0")/lib.sh"
NS=lifecycle-embedded-pg
trap 'cleanup_ns "$NS"' EXIT

log "Scenario 2: embedded PostgreSQL with persistence"
gen_min_values
helm install "$RELEASE" "$CHART" -n "$NS" --create-namespace -f "$GEN/min.yaml" \
  --set postgresql.persistence.enabled=true \
  --set postgresql.persistence.storageClassName="$STORAGE_CLASS"
wait_ready "$NS"

pvc="$RELEASE-db-data"
[[ -n "$pvc" ]] || fail "PostgreSQL PVC was not created"
[[ "$(kubectl get pvc "$pvc" -n "$NS" -o jsonpath='{.status.phase}')" == Bound ]] \
  || fail "PostgreSQL PVC is not Bound"
pass "PostgreSQL PVC is Bound"

psql_in "$NS" "create table lifecycle_persistence(value int); insert into lifecycle_persistence values (42);" >/dev/null
kubectl delete pod -n "$NS" "$RELEASE-postgresql-0"
kubectl wait --for=condition=ready pod "$RELEASE-postgresql-0" -n "$NS" --timeout="$WAIT_TIMEOUT"
[[ "$(psql_in "$NS" 'select value from lifecycle_persistence;')" == 42 ]] \
  || fail "database data did not survive the PostgreSQL pod restart"
pass "database data survived a PostgreSQL pod restart"

tables="$(psql_in "$NS" "select count(*) from information_schema.tables where table_schema='public';")"
(( tables > 1 )) || fail "Heimdall database migrations were not detected"
pass "Heimdall database schema was migrated"
