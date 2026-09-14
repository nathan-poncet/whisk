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
    └── …                   AppDelegate · HistoryStorage · PanelWiring · PanelKeyRouter ·
                            NSPanel · Timer · hot key · CGEvent
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
   reads it once before trusting it, sets an unreadable one aside, falls
   back to memory, and imports the legacy history. Two pieces of this
   ring hold rules rather than wiring and are kept apart so they can be
   tested: `PanelWiring` builds the panel's action table (which actions
   flush the search debounce, which close and paste), and `PanelKeyRouter`
   turns key presses into actions — vim's normal mode, the user's
   bindings, ⌘digits. `AppDelegate` only assembles. Async lives here and
   only here.

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
`FailingHistoryStore`, `SaveFailingHistoryStore`, `ScriptedPasteboard`,
`RecordingLogger`. Test names state behaviour
(`a_storage_failure_is_logged_and_the_presented_state_stays_alive`).

- **Kernel and adapters** are covered line by line: history behaviour,
  every use case, the controller's navigation and facets, the presenter's
  strings, icons and VoiceOver labels. The `HistoryStore` contract is one
  parameterized suite run against every gateway (SQLite, in-memory) in a
  fresh temporary directory per test; a raw connection sabotages the
  schema to reach every error path. The legacy JSON reader is tested
  against a fixture of its on-disk format, the storage bootstrap against
  corrupt, drifted and legacy directories, the pasteboard gateway against
  a private pasteboard, the string catalogs against the code that reads
  them.
- **The frameworks ring is tested without a screen.** Views are drawn
  off screen with `ImageRenderer` in every state they can be in, and
  hosted in a window that is never ordered in so the behind-window blur
  gets a layer and a layout pass; the panel is fed state changes and
  pumped through the run loop so its observers run. Key routing is driven
  by synthetic `NSEvent`s, the debouncer by a hand-cranked scheduler, the
  update check by canned replies, QuickLook and LinkPresentation by
  awaiting their published values. A test never shows a window.
- **Outside the suite, on purpose:** `AppDelegate` (status item, global
  hot keys, timers — the composition root the release smoke test covers),
  `HotKey` (registering one would hijack the tester's shortcut),
  `PasteSimulator` (posts ⌘V to the frontmost app), `main`, and the
  parts of `PanelController` that order windows in. `scripts/coverage.sh`
  runs the suite with coverage and prints the report CI archives.
