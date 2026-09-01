#!/usr/bin/env bash
# The Dependency Rule, enforced: inner rings may only import what their ring
# allows. Run from the repository root; CI runs it on every push.
set -euo pipefail

violations=0

check_ring() {
  local dir="$1"
  shift
  local allowed=("$@")

  [ -d "$dir" ] || return 0

  while IFS= read -r hit; do
    local file="${hit%%:*}"
    local rest="${hit#*:}"
    local line="${rest%%:*}"
    local statement="${rest#*:}"
    local module
    module=$(echo "$statement" | sed -e 's/^import //' -e 's/[.].*$//' -e 's/ .*$//')

    local ok=0
    for candidate in "${allowed[@]}"; do
      if [ "$module" = "$candidate" ]; then
        ok=1
        break
      fi
    done

    if [ "$ok" -eq 0 ]; then
      echo "Dependency Rule violation: $file:$line imports $module (ring allows: ${allowed[*]})"
      violations=1
    fi
  done < <(grep -rn '^import ' "$dir" --include='*.swift' || true)
}

check_ring "Sources/Whisk/Entities" Foundation
check_ring "Sources/Whisk/UseCases" Foundation
check_ring "Sources/Whisk/Adapters/Controllers" Foundation
check_ring "Sources/Whisk/Adapters/Presenters" Foundation
check_ring "Sources/Whisk/Adapters/Gateways" Foundation AppKit SQLite3

if [ "$violations" -ne 0 ]; then
  echo "The Dependency Rule is broken. Arrows point inward only."
  exit 1
fi

echo "Dependency Rule: OK"
