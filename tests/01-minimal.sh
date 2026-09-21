#!/usr/bin/env bash
# Scenario 1: bare-minimum values.yaml, spin up and spin down.
source "$(dirname "$0")/lib.sh"
NS=t1-minimal
trap 'cleanup_ns $NS' EXIT

log "Scenario 1: minimal values"
gen_min_values
helm lint "$CHART" -f "$GEN/min.yaml"
helm install "$RELEASE" "$CHART" -n "$NS" --create-namespace -f "$GEN/min.yaml"
wait_ready "$NS"
pass "both pods Ready"

[[ -z "$(kubectl get pvc -n "$NS" -o name)" ]] || fail "unexpected PVC with persistence off"
check_http "$NS"

log "Spin down"
helm uninstall "$RELEASE" -n "$NS"
kubectl wait --for=delete pod --all -n "$NS" --timeout=120s
left="$(kubectl get statefulset,svc,secret,ingress,pvc -n "$NS" -o name | grep -v kube-root || true)"
[[ -z "$left" ]] || fail "resources left after uninstall: $left"
pass "uninstall left nothing behind"
