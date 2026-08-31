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
- **Liquid Glass panel** — `⇧⌘V` opens a floating glass panel (the macOS 26
  look, translucent materials on earlier systems); click a card to copy it
  back (and paste it directly when Accessibility access is granted). The
  shortcut follows your keyboard layout — `V` is wherever your layout
  prints it (Dvorak, AZERTY, Colemak, …), re-resolved live when you switch
  layouts.
- **Per-app styling** — each card carries the icon of the application it
  was copied from and takes its tint from that app's icon.
- **Search** — type to filter text, links and file names instantly; `Return`
  selects the first match.
- **Filters** — a chip bar narrows the rail by source application (one chip
  per app, with its icon) and by content category (text, code, color, link,
  image, files); chips combine with each other and with the search query.
- **Pins** — right-click a card to pin it; pinned items survive
  *Clear* and are never evicted.
- **Rich previews** — copied links show the page's title, favicon and lead
  image; files show a QuickLook thumbnail; images render inline; hex codes
  become color swatches.
- **Syntax highlighting** — text that reads as code is detected and
  highlighted (keywords, strings, comments, numbers), language-agnostic.
- **Privacy** — history stays on disk in
  `~/Library/Application Support/Whisk`; password managers marking their
  content as concealed (`org.nspasteboard.ConcealedType`) are never
  recorded. One exception to "nothing leaves your machine": link previews
  fetch metadata from the copied URL over the network (cached, once per
  link).

## Requirements

- macOS 14 or later to run (Liquid Glass on macOS 26, material fallback
  before that)
- The macOS 26 SDK to build (Xcode 26+, or matching Command Line Tools —
  running the test suite requires Xcode)

## Install

With Homebrew (builds from source, needs the macOS 26 SDK):

```sh
brew install nathan-poncet/tap/whisk
whisk
```

Then link it into /Applications if you want it in Launchpad — the path is
printed in the install caveats.

## Run it from source

```sh
git clone https://github.com/nathan-poncet/whisk.git
cd whisk
swift run Whisk
```

To build a proper app bundle (icon, Info.plist, menu-bar-only):

```sh
./scripts/build-app.sh 0.0.0 native   # → dist/Whisk.app
```

The clipboard icon appears in the menu bar. Copy a few things, then press
`⇧⌘V`.

- **Left-click** the menu bar icon (or `⇧⌘V`): toggle the panel.
- **Right-click** the icon: menu (show, clear, quit).
- **Arrow keys** (`←`/`↑` previous, `→`/`↓` next): step through the cards —
  the panel scrolls to keep the selection in view.
- **Return**: paste the selected card into the text field that had focus
  before the panel opened. The panel never steals focus, so the caret is
  exactly where you left it; the first use prompts for Accessibility
  access (System Settings → Privacy & Security → Accessibility), and until
  it is granted the card still lands on the clipboard for a manual `⌘V`.
- **Click a card**: same as Return, for that card.
- **Right-click a card**: pin or delete.
- **Esc** or click outside: close the panel.

You can also open `Package.swift` in Xcode and run the `Whisk` scheme.

## Tests

```sh
swift test
```

The suites cover history behaviour (dedup, capacity, pins, search),
controller orchestration, and presenter formatting with deterministic
fakes — frozen clock, scripted pasteboard, in-memory store. A contract
suite runs the `HistoryStore` port against the file gateway in a temporary
directory. The Dependency Rule is linted by
`./scripts/check-dependency-rule.sh`. CI runs everything on every push.

## CI & releases

Every push runs the Dependency Rule lint, `swift format lint --strict`,
the build, and the tests ([ci.yml](.github/workflows/ci.yml)). Renovate
keeps the GitHub Actions (and any future package dependencies) up to date.

Pushing a tag `v*` runs [release.yml](.github/workflows/release.yml): it
tests, builds a universal (arm64 + x86_64) `Whisk.app`, attaches the zip to
a GitHub release, and bumps the Homebrew formula in
[nathan-poncet/homebrew-tap](https://github.com/nathan-poncet/homebrew-tap)
(requires a `TAP_GITHUB_TOKEN` repository secret with write access to the
tap).

```sh
git tag v0.2.0 && git push origin v0.2.0
```

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
