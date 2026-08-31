# Whisk

An open-source clipboard manager for macOS, inspired by
[Paste](https://pasteapp.io/). A menu bar app that remembers everything you
copy — text, links, images, files, colors — and brings it back through a
Paste-style panel at the bottom of your screen.

Built in Swift/SwiftUI following Clean Architecture: a pure, synchronous
kernel behind ports, adapters at the edges, and a composition root that wires
them together. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
([français](docs/fr/ARCHITECTURE.md)).

## Features

- **Clipboard history** — every copy is captured and persisted locally,
  newest first, deduplicated.
- **Paste-style panel** — `⇧⌘V` opens a bottom panel with one card per item;
  click a card to copy it back (and paste it directly when Accessibility
  access is granted).
- **Search** — type to filter text, links and file names instantly; `Return`
  selects the first match.
- **Pins** — right-click a card to pin it; pinned items survive
  *Clear* and are never evicted.
- **Rich previews** — images, links, file lists, and color swatches for
  copied hex codes.
- **Privacy** — everything stays on disk in
  `~/Library/Application Support/Whisk`; password managers marking their
  content as concealed (`org.nspasteboard.ConcealedType`) are never recorded.

## Requirements

- macOS 14 or later
- Swift 6 toolchain (Xcode 16+, or Command Line Tools for building only —
  running the test suite requires Xcode)

## Run it

```sh
git clone https://github.com/nathan-poncet/whisk.git
cd whisk
swift run Whisk
```

The clipboard icon appears in the menu bar. Copy a few things, then press
`⇧⌘V`.

- **Left-click** the menu bar icon (or `⇧⌘V`): toggle the panel.
- **Right-click** the icon: menu (show, clear, quit).
- **Click a card**: copy it back to the clipboard. If the app that launched
  Whisk (e.g. your terminal) has Accessibility permission
  (System Settings → Privacy & Security → Accessibility), the item is pasted
  straight into the frontmost app.
- **Right-click a card**: pin or delete.
- **Esc** or click outside: close the panel.

You can also open `Package.swift` in Xcode and run the `Whisk` scheme.

## Tests

```sh
swift test
```

The kernel suite covers history behaviour (dedup, capacity, pins, search)
with deterministic fakes — frozen clock, scripted pasteboard, in-memory
store. A contract suite runs the `HistoryStore` port against the file
adapter in a temporary directory. CI runs both on every push.

## Status & roadmap

This is a working prototype, not a Paste replacement (yet). Not implemented:

- iCloud sync and iOS/iPadOS companion app
- Shared pinboards
- Keyboard navigation inside the panel (arrow keys)
- Preferences (hotkey, capacity, excluded apps)
- Launch at login, signed/notarized release builds

Contributions welcome — see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
for the rules the codebase follows.

## License

[MIT](LICENSE)
