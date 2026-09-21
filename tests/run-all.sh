#!/usr/bin/env bash
# Runs every scenario in order against the current kubectl context.
#   RUN_KNOWN_ISSUES=1  also assert the documented known issues (CNPG image, sops/ kustomize)
#   ONLY="01 04"        run only the listed scenario prefixes
source "$(dirname "$0")/lib.sh"
require helm kubectl openssl curl
check_context

failed=()
for s in "$TESTS_DIR"/0*.sh; do
  base="$(basename "$s")"
  if [[ -n "${ONLY:-}" && ! " $ONLY " == *" ${base:0:2} "* ]]; then continue; fi
  bash "$s" || failed+=("$base")
done

echo
if ((${#failed[@]})); then
  printf '\033[31mFAILED:\033[0m %s\n' "${failed[*]}"; exit 1
fi
printf '\033[32mAll scenarios passed\033[0m\n'
