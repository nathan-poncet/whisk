# Working conventions for Claude

Clipboard manager for macOS (Swift/SwiftUI, Clean Architecture, TDD).
Architecture rules: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). The essentials:

## Language & history
- Code, comments, and commit messages in **English**. French docs mirror under `docs/fr/`.
- Prefix commits and issues with a **Gitmoji** (📝 docs, ✨ feat, ✅ tests, ♻️ refactor, 👷 ci, 🔒 security…).

## Design
- One simple app module; the rings are folders: `Entities/` and `UseCases/` (+ `Ports/`)
  import Foundation only; `Adapters/{Controllers, Presenters, Gateways}` is the
  interface-adapters ring (only `Gateways/` may import AppKit); `App/` is frameworks &
  drivers plus the composition root.
- The Dependency Rule is enforced by `scripts/check-dependency-rule.sh` — run it before
  pushing; CI runs it on every push.
- Views are dumb: they render the presenter's `HistoryViewState` verbatim; every display
  decision (labels, relative times, previews) belongs to the presenter.
- Newtypes over primitives; make illegal states unrepresentable.
- Fail closed: no force-unwraps in production paths; a storage failure never kills the UX.

## Comments
- Prefer **self-documenting code**: precise names, small functions, strong types.
- Add a comment **only** for a non-obvious *why* the code cannot express — never to restate *what* the code does.
- Never reference planning artifacts (issue IDs, milestones) in code.

## Tests
- TDD: red first; test names state behaviour (`a_duplicate_copy_moves_the_existing_item_to_the_front`), never `testFoo1`.
- Deterministic always: frozen clocks, scripted pasteboards, temp directories.
- Port contract suites run against every adapter of that port.
- `swift test` needs a full Xcode toolchain; CI runs it on every push.
