# Architecture

Whisk follows Clean Architecture: entities and use cases alone at the
center of the onion, a full interface-adapters ring around them
(controllers, presenters, gateways), and frameworks at the very edge. The
SwiftPM target graph *is* the Dependency Rule — every arrow points inward.

## The map

```
        Whisk  (executable — frameworks & drivers + composition root, sink)
        SwiftUI views · NSPanel · NSStatusItem · Timer · hot key · CGEvent
                │ may name everything
   ┌────────────┼───────────────────────┬─────────────────────┐
   ▼            ▼                       ▼                     ▼
WhiskAdapters   HistoryStoreFile   PasteboardAppKit      WhiskTestKit
controllers +   gateway (files)    gateway (NSPasteboard)  fakes for tests
presenters      │                       │                     │
   └────────────┴───────────┬───────────┴─────────────────────┘
                            ▼
                       WhiskKernel
                 entities · use cases · ports
```

## The rings

1. **Kernel (entities + use cases).** `WhiskKernel` holds `Entities/` and
   `UseCases/` with its `UseCases/Ports/`. It imports Foundation only —
   never AppKit, never SwiftUI. Ports are role-noun protocols
   (`Pasteboard`, `HistoryStore`, `Clock`), one file per port, each owning
   its error type. Use cases are generic over their ports and stay
   synchronous and pure; time comes in through `Clock`.
2. **Interface adapters.**
   - *Controllers* (`WhiskAdapters/Controllers`): translate UI and OS
     events into use case invocations. `ClipboardController` receives the
     gateways, builds the use cases, owns the current `History` and search
     query, and handles storage failures without killing the session.
   - *Presenters* (`WhiskAdapters/Presenters`): pure entity → view-state
     mapping. `HistoryPresenter` decides every display string (kind labels,
     relative times, hex-color detection, file-list truncation) and emits a
     `HistoryViewState` that views render verbatim. It never reads the
     system clock — `now` is an argument.
   - *Gateways* (`HistoryStoreFile`, `PasteboardAppKit`): implement the
     kernel's ports. They live in separate targets named `<Role><Tech>` so
     a framework dependency (AppKit) never leaks into the rest of the ring.
3. **Frameworks & drivers.** The `Whisk` executable is the composition
   root and a sink: SwiftUI views (dumb renderers of `HistoryViewState`),
   the floating `NSPanel`, the menu bar item, the polling `Timer`, the
   Carbon hot key, and paste simulation. Async lives here and only here.

## Invariants

- **Newtypes over primitives; illegal states unrepresentable.**
  `HistoryCapacity` rejects zero at construction; `History` enforces its
  own eviction invariant in every mutation.
- **Fail closed.** No force-unwraps in production paths. A storage failure
  is logged and the in-memory history keeps working; a corrupt persisted
  entry is skipped, never fatal.
- **Opaque bytes cross seams.** The kernel and the view state carry image
  payloads as `Data`. `PasteboardAppKit` owns PNG normalization;
  `HistoryStoreFile` owns the JSON index format and pins dates to whole
  milliseconds so a saved history loads back identically.

## Tests

- `WhiskTestKit` is the shared test kit: `FakeClock`,
  `InMemoryHistoryStore`, `FailingHistoryStore`, `ScriptedPasteboard` —
  deterministic doubles for every port.
- Kernel behaviour, controller orchestration, and presenter formatting
  each have their own suite; test names state behaviour
  (`a_storage_failure_keeps_the_presented_state_alive`).
- The `HistoryStore` port has a contract suite run against the file
  adapter in a fresh temporary directory per test. Any future gateway
  (SQLite, CloudKit) must pass the same contract.
