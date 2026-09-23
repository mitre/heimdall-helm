#!/usr/bin/env bash
# Run every lifecycle scenario against the current disposable Kubernetes context.
# Use ONLY="01 04" to select scenario prefixes.
source "$(dirname "$0")/lib.sh"
require helm kubectl openssl curl
check_context

log "Build chart dependencies"
helm dependency build "$CHART"

failed=()
for scenario in "$TESTS_DIR"/0*.sh; do
  base="$(basename "$scenario")"
  if [[ -n "${ONLY:-}" && ! " $ONLY " == *" ${base:0:2} "* ]]; then
    continue
  fi
  bash "$scenario" || failed+=("$base")
done

echo
if ((${#failed[@]})); then
  printf '\033[31mFAILED:\033[0m %s\n' "${failed[*]}"
  exit 1
fi
printf '\033[32mAll lifecycle scenarios passed\033[0m\n'
