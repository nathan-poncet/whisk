# Contributing to Whisk

Thanks for helping! Whisk is a small codebase with strict rules — this page
is everything you need to get a green PR on the first try.

## Setup

```sh
git clone https://github.com/nathan-poncet/whisk.git
cd whisk
swift run Whisk
```

**Toolchain:** building needs the macOS 26 SDK (Xcode 26+, or the matching
Command Line Tools). `swift build` works with Command Line Tools alone, but
**`swift test` requires a full Xcode installation** — if you only have CLT,
push your branch and let CI run the suite (it runs on every push).

Useful entry points while developing:

```sh
swift run Whisk --show-panel      # open the history panel immediately
swift run Whisk --show-settings   # open the Settings window immediately
./scripts/build-app.sh 0.0.0 native   # package a real Whisk.app into dist/
```

## Before you push

CI runs exactly these, in this order — run them locally first:

```sh
./scripts/check-dependency-rule.sh
swift format lint --strict --recursive Sources Tests Package.swift
swift build
swift test        # needs Xcode; otherwise let CI run it
```

`swift format format --in-place --recursive Sources Tests` fixes most lint
complaints automatically.

## Architecture in one minute

Whisk follows Clean Architecture inside a single module — the rings are
folders, and the Dependency Rule (source dependencies only point inward) is
enforced by `scripts/check-dependency-rule.sh`:

| Ring | Folder | May import |
|---|---|---|
| Entities | `Sources/Whisk/Entities/` | Foundation |
| Use cases | `Sources/Whisk/UseCases/` (+ `Ports/`) | Foundation |
| Interface adapters | `Sources/Whisk/Adapters/{Controllers,Presenters,Gateways}/` | Foundation (Gateways may also use AppKit + SQLite3) |
| Frameworks & drivers | `Sources/Whisk/App/` | anything |

Ground rules:

- **Views are dumb.** They render the presenter's `HistoryViewState`
  verbatim. Every display decision — labels, relative times, previews —
  belongs to the presenter.
- **The kernel is pure and synchronous.** Time comes in as a value
  (`Clock` port), the pasteboard and storage sit behind ports.
- **Fail closed.** No force-unwraps in production paths; a storage failure
  must never take the UI down.
- Full rules with diagrams: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
  ([français](docs/fr/ARCHITECTURE.md)).

## Tests

TDD is the house style: write the failing test first. Conventions:

- Test names state behaviour:
  `a_duplicate_copy_moves_the_existing_item_to_the_front`, never `testFoo1`.
- Deterministic always — frozen clocks, scripted pasteboards, temporary
  directories. No sleeps, no real pasteboard, no network.
- A port gets a **contract suite** that runs against every gateway
  implementing it (see `FileHistoryStoreTests`, which exercises both the
  JSON and SQLite stores).

## User-facing strings

Every user-visible string goes through the `localized()` helper and needs
an entry in **both** `Sources/Whisk/Resources/en.lproj/Localizable.strings`
and `fr.lproj/Localizable.strings` (the key is the English text).

## Commits & PRs

- Code, comments and commit messages are in **English**; French docs mirror
  under `docs/fr/`.
- Prefix commit subjects with a [Gitmoji](https://gitmoji.dev): ✨ feature,
  🐛 fix, ♻️ refactor, ✅ tests, 📝 docs, 👷 CI, 🌐 i18n, 🔒 security…
- Keep PRs focused: one feature or fix per PR, with tests for behaviour
  changes.
- `main` is protected — all changes land through a PR with CI green.

## Reporting bugs & proposing features

Use the issue templates. For bugs, the macOS version and your keyboard
layout matter more often than you'd think (shortcuts are layout-aware).
