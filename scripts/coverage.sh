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
