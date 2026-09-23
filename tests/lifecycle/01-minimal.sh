#!/usr/bin/env bash
# Bare-minimum values: install, validate, and uninstall cleanly.
source "$(dirname "$0")/lib.sh"
NS=lifecycle-minimal
trap 'cleanup_ns "$NS"' EXIT

log "Scenario 1: bare-minimum lifecycle"
gen_min_values
helm lint "$CHART" -f "$GEN/min.yaml"
helm install "$RELEASE" "$CHART" -n "$NS" --create-namespace -f "$GEN/min.yaml"
wait_ready "$NS"
check_http "$NS"

[[ -z "$(kubectl get pvc -n "$NS" -o name)" ]] || fail "unexpected PVC with persistence disabled"

log "Spin down"
helm uninstall "$RELEASE" -n "$NS"
kubectl wait --for=delete pod --all -n "$NS" --timeout=120s
left="$(kubectl get all,configmap,secret,pvc,serviceaccount,networkpolicy,pdb \
  -n "$NS" -l app.kubernetes.io/instance="$RELEASE" -o name 2>/dev/null || true)"
[[ -z "$left" ]] || fail "resources remained after uninstall: $left"
pass "install, HTTP validation, and clean uninstall"
