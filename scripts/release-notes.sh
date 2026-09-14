#!/usr/bin/env bash
# Prints the CHANGELOG.md section of one version (e.g. 0.8.5), body only,
# for the GitHub release notes. Exits 1 when the version has no section,
# so the release workflow can fall back to generated notes.
set -euo pipefail

version="${1:?usage: release-notes.sh VERSION}"

notes="$(
  awk -v version="$version" '
    /^## \[/ {
      if (printing) exit
      printing = ($0 ~ "^## \\[" version "\\]")
      next
    }
    printing { print }
  ' CHANGELOG.md | sed '/./,$!d'
)"

if [ -z "$notes" ]; then
  echo "CHANGELOG.md has no section for $version" >&2
  exit 1
fi
printf '%s\n' "$notes"
