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
│   └── Ports/              TogglePin · DeleteItem · ClearHistory · LoadHistory
│                           Pasteboard · HistoryStore · Clock        (Foundation only)
├── Adapters/
│   ├── Controllers/        ClipboardController                     (Foundation only)
│   ├── Presenters/         HistoryPresenter · HistoryViewState     (Foundation only)
│   └── Gateways/           FileHistoryStore · AppKitPasteboard     (Foundation + AppKit)
└── App/                    frameworks & drivers + composition root (anything goes)
    ├── Views/              SwiftUI renderers of HistoryViewState
    └── …                   AppDelegate · NSPanel · Timer · hot key · CGEvent
```

## The rings

1. **Kernel (entities + use cases).** `Entities/` and `UseCases/` with its
   `UseCases/Ports/` import Foundation only — never AppKit, never SwiftUI.
   Ports are role-noun protocols (`Pasteboard`, `HistoryStore`, `Clock`),
   one file per port, each owning its error type. Use cases are generic
   over their ports and stay synchronous and pure; time comes in through
   `Clock`.
2. **Interface adapters.**
   - *Controllers*: translate UI and OS events into use case invocations.
     `ClipboardController` receives the gateways, builds the use cases,
     owns the current `History` and search query, and handles storage
     failures without killing the session.
   - *Presenters*: pure entity → view-state mapping. `HistoryPresenter`
     decides every display string (kind labels, relative times, hex-color
     detection, file-list truncation) and emits a `HistoryViewState` that
     views render verbatim. It never reads the system clock — `now` is an
     argument.
   - *Gateways*: implement the kernel's ports. `FileHistoryStore` owns the
     JSON-index-plus-blobs persistence format; `AppKitPasteboard` owns the
     NSPasteboard boundary. This is the only ring folder allowed to import
     AppKit.
3. **Frameworks & drivers (`App/`).** The composition root and everything
   framework-shaped: SwiftUI views (dumb renderers of `HistoryViewState`),
   the floating `NSPanel`, the menu bar item, the polling `Timer`, the
   Carbon hot key, paste simulation. Async lives here and only here.

## Invariants

- **Newtypes over primitives; illegal states unrepresentable.**
  `HistoryCapacity` rejects zero at construction; `SourceApp` guarantees at
  least one identifying field; `History` enforces its own eviction
  invariant in every mutation.
- **Fail closed.** No force-unwraps in production paths. A storage failure
  is logged and the in-memory history keeps working; a corrupt persisted
  entry is skipped, never fatal.
- **Opaque bytes cross seams.** The kernel and the view state carry image
  payloads as `Data`. The pasteboard gateway owns PNG normalization; the
  file gateway owns the JSON index format and pins dates to whole
  milliseconds so a saved history loads back identically.

## Tests

One `WhiskTests` target (`@testable import Whisk`) with deterministic
doubles in `Fakes.swift`: `FakeClock`, `InMemoryHistoryStore`,
`FailingHistoryStore`, `ScriptedPasteboard`. Kernel behaviour, controller
orchestration, and presenter formatting each have their own suite; test
names state behaviour (`a_storage_failure_keeps_the_presented_state_alive`).
The `HistoryStore` port has a contract suite run against the file gateway
in a fresh temporary directory per test; any future gateway (SQLite,
CloudKit) must pass the same contract.
