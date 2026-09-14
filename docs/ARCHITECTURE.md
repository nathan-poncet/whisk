# Architecture

Whisk is one simple Swift application that follows Clean Architecture:
entities and use cases alone at the center of the onion, a full
interface-adapters ring around them (controllers, presenters, gateways),
and frameworks at the very edge. The rings live as folders in a single
module; the Dependency Rule is enforced by
`scripts/check-dependency-rule.sh`, which CI runs on every push — inner
rings may only import what their ring allows, arrows point inward only.

## The map

```
Sources/Whisk/
├── Entities/               History · ClipboardItem · Payload · SourceApp · HistoryCapacity
├── UseCases/               CaptureClipboardChange · SelectItem · FilterHistory ·
│   └── Ports/              TogglePin · DeleteItem · ClearHistory · LoadHistory · EnforceRetention
│                           Pasteboard · HistoryStore · Clock · Logger  (Foundation only)
├── Adapters/
│   ├── Controllers/        ClipboardController                     (Foundation only)
│   ├── Presenters/         HistoryPresenter · HistoryViewState     (Foundation only)
│   └── Gateways/           SQLiteHistoryStore · LegacyJSONHistory · VolatileHistoryStore ·
│                           AppKitPasteboard · ConsoleLogger        (Foundation + AppKit + SQLite3)
└── App/                    frameworks & drivers + composition root (anything goes)
    ├── Views/              SwiftUI renderers of HistoryViewState
    └── …                   AppDelegate · HistoryStorage · NSPanel · Timer · hot key · CGEvent
```

## The rings

1. **Kernel (entities + use cases).** `Entities/` and `UseCases/` with its
   `UseCases/Ports/` import Foundation only — never AppKit, never SwiftUI.
   Ports are role-noun protocols (`Pasteboard`, `HistoryStore`, `Clock`,
   `Logger`), one file per port, each owning its error type. Use cases are
   generic over their ports and stay synchronous and pure; time comes in
   through `Clock`.
2. **Interface adapters.**
   - *Controllers*: translate UI and OS events into use case invocations.
     `ClipboardController` receives the gateways, builds the use cases,
     owns the current `History`, search query and keyboard selection, and
     reports storage failures to the `Logger` without killing the session.
   - *Presenters*: pure entity → view-state mapping. `HistoryPresenter`
     decides every display string and symbol (kind labels, relative
     times, the empty-state sentence, chip icons, hex-color detection,
     file-list truncation) and emits a `HistoryViewState` that views
     render verbatim. It never reads the system clock — `now` is an
     argument. `ChipEntry.row` decides the order of the filter chips
     once; the controller steers the keyboard along that same list.
   - *Gateways*: implement the kernel's ports. `SQLiteHistoryStore` owns
     the production schema; `LegacyJSONHistory` reads the pre-SQLite JSON
     index for the one-time import; `VolatileHistoryStore` keeps a
     session alive when no database can be opened; `AppKitPasteboard`
     owns the NSPasteboard boundary; `ConsoleLogger` writes to the
     unified log. This is the only ring folder allowed to import AppKit.
3. **Frameworks & drivers (`App/`).** The composition root and everything
   framework-shaped: SwiftUI views (dumb renderers of `HistoryViewState`),
   the floating `NSPanel`, the menu bar item, the polling `Timer`, the
   Carbon hot key, paste simulation. `HistoryStorage` opens the database,
   sets an unreadable one aside, falls back to memory, and imports the
   legacy history. Async lives here and only here.

## Invariants

- **Newtypes over primitives; illegal states unrepresentable.**
  `HistoryCapacity` rejects zero at construction; `SourceApp` guarantees at
  least one identifying field; `History` enforces its own eviction
  invariant in every mutation.
- **Fail closed.** No force-unwraps in production paths. A storage failure
  is logged and the in-memory history keeps working; a corrupt persisted
  entry is skipped, never fatal; a database that will not open is set
  aside and the session runs in memory rather than refusing to launch.
- **Opaque bytes cross seams.** The kernel and the view state carry image
  payloads as `Data`. The pasteboard gateway owns PNG normalization; the
  SQLite gateway owns the schema and pins dates to whole milliseconds so a
  saved history loads back identically.

## Tests

One `WhiskTests` target (`@testable import Whisk`) with deterministic
doubles in `Fakes.swift`: `FakeClock`, `InMemoryHistoryStore`,
`FailingHistoryStore`, `ScriptedPasteboard`, `RecordingLogger`. Kernel
behaviour, controller orchestration, and presenter formatting each have
their own suite; test names state behaviour
(`a_storage_failure_is_logged_and_the_presented_state_stays_alive`). The
`HistoryStore` contract is one parameterized suite run against every
gateway (SQLite, in-memory) in a fresh temporary directory per test; a
new gateway joins by adding a case. The legacy JSON reader is tested
against a fixture of its on-disk format, the storage bootstrap against
corrupt and legacy directories, the pasteboard gateway against a private
pasteboard, and the string catalogs against the code that reads them.
`scripts/coverage.sh` runs the suite with coverage and prints the report
CI archives.
