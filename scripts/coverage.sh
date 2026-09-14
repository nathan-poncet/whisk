#!/usr/bin/env bash
# Runs the test suite with code coverage, prints a per-file report for the
# app sources and leaves an LCOV export in .build/coverage.lcov. Needs a
# full Xcode toolchain, like `swift test` itself. Run from the repository
# root; CI runs it on every push and archives both outputs.
set -euo pipefail

swift test --enable-code-coverage "$@"

codecov="$(swift test --show-codecov-path)"
profdata="$(dirname "$codecov")/default.profdata"
bundle="$(find "$(dirname "$(dirname "$codecov")")" -maxdepth 1 -name '*.xctest' | head -n 1)"
binary="$bundle/Contents/MacOS/$(basename "$bundle" .xctest)"
ignore='(/Tests/|/\.build/)'

xcrun llvm-cov export "$binary" -instr-profile "$profdata" -ignore-filename-regex="$ignore" -format=lcov \
  > .build/coverage.lcov
xcrun llvm-cov report "$binary" -instr-profile "$profdata" -ignore-filename-regex="$ignore" -use-color=false

# The gate measures what a unit test can reach. Four files stay out of
# it because exercising them has side effects no test may have: the
# composition root (status item, timers, global shortcuts), the Carbon
# hot key, the paste simulation that sends ⌘V, and the entry point. They
# are still in the report above.
untestable='AppDelegate\.swift|HotKey\.swift|PasteSimulator\.swift|main\.swift'
gated="$(xcrun llvm-cov report "$binary" -instr-profile "$profdata" \
  -ignore-filename-regex="(/Tests/|/\.build/|$untestable)" -use-color=false \
  | awk '$1 == "TOTAL" { print $10 }' | tr -d '%')"
echo "Coverage gate: ${gated}% of testable lines (minimum ${COVERAGE_MIN:-not set})"
if [ -n "${COVERAGE_MIN:-}" ]; then
  awk -v got="$gated" -v min="$COVERAGE_MIN" 'BEGIN { exit (got + 0 >= min + 0) ? 0 : 1 }' || {
    echo "Line coverage of the testable code fell under ${COVERAGE_MIN}%." >&2
    exit 1
  }
fi
