# Architecture

Pasteur follows Clean Architecture: a pure kernel behind ports, adapters at
the edges, one composition root. The SwiftPM target graph *is* the
Dependency Rule — the kernel depends on nothing of ours, adapters depend
only on the kernel, and only the executable may name everything.

## The map

```
                      Pasteur  (executable — composition root, sink)
                         │ may name everything
          ┌──────────────┼──────────────────┐
          ▼              ▼                  ▼
   PasteurKernel   HistoryStoreFile   PasteboardAppKit
                         │ (adapter)        │ (adapter)
                         └──────────┬───────┘
                                    ▼
                            PasteurKernel
```

## The rules

1. **One bounded context.** `PasteurKernel` holds `Entities/` and
   `UseCases/` with its `UseCases/Ports/`. It imports Foundation only —
   never AppKit, never SwiftUI.
2. **Ports live in the kernel**, one file per port, role-noun names
   (`Pasteboard`, `HistoryStore`, `Clock`); `HistoryStore` owns its
   `HistoryStoreError`.
3. **Adapters are separate targets**, named `<Role><Tech>`
   (`HistoryStoreFile`, `PasteboardAppKit`); each depends on the kernel and
   on nothing else of ours.
4. **The composition root is a sink.** The `Pasteur` executable wires
   adapters into use cases (`UseCaseBundle`) and owns all UI; nothing
   depends on it.
5. **Sync, pure core; time at the edge.** Use cases are synchronous and
   take their clock as a port. The polling timer lives in the app, not in
   the kernel.
6. **Newtypes over primitives; illegal states unrepresentable.**
   `HistoryCapacity` rejects zero at construction; `History` enforces its
   own eviction invariant in every mutation.
7. **Fail closed.** No force-unwraps in production paths. A storage failure
   is logged and the in-memory history keeps working; a corrupt persisted
   entry is skipped, never fatal.
8. **Opaque bytes cross seams.** The kernel sees image payloads as `Data`.
   `PasteboardAppKit` owns the PNG normalization; `HistoryStoreFile` owns
   the JSON index format and pins dates to whole milliseconds so a saved
   history loads back identically.

## Tests

- Kernel behaviour is tested with deterministic fakes: a frozen `FakeClock`,
  a `ScriptedPasteboard`, an `InMemoryHistoryStore`. Test names state
  behaviour (`a_duplicate_copy_moves_the_existing_item_to_the_front…`).
- The `HistoryStore` port has a contract suite run against the file adapter
  in a fresh temporary directory per test. Any future adapter (SQLite,
  CloudKit) must pass the same contract.
