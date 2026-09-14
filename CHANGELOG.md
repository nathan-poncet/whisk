# Changelog

All notable changes to Whisk are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions
[Semantic Versioning](https://semver.org/). Entries describe what a user
of the app notices; the landing page, the docs and the build pipeline
live in the commit history.

## [Unreleased]

### Changed
- In the editor, `Return` saves and `⇧⏎` breaks the line, in both input
  modes; `⌘S` no longer saves there — it is the card's Save As… shortcut.
  The button and `Esc` work as before, and the editor says so.

## [0.10.0] - 2026-09-14

### Added
- Link previews can be switched off in Settings, under Privacy: no
  request leaves the Mac and link cards show the bare address, including
  for links already looked up.
- The panel rises on the screen where the pointer is, and the preview
  follows it, instead of always on the main screen.
- Cards come in three sizes — small, medium, large — chosen in Settings;
  the panel's height follows.
- The letters a search matched are washed in the accent color on text
  and code cards, so the eye lands on why a card is there.
- "Paste as…" in a text or link card's menu pastes it rewritten: upper or
  lower case, trimmed, single line, without accents, URL- or
  base64-encoded or decoded, formatted JSON. The card stays as copied.
- A card's menu now offers everything it can do: copy without pasting
  (`⌘C`), paste as plain text, open the link (`⌘O`), reveal the files in
  Finder (`⌘R`), add to or remove from the paste stack, save as a file
  (`⌘S`), exclude its application (`⌃⌘X`), delete everything from its
  application (`⌃⌘⌫`, pins survive). Every shortcut is rebindable and has
  a vim key: `y`, `o`, `r`, `w`, `X`, `D`.
- A card's text can be edited in place: `⌘E`, the vim `e` or "Edit…" open
  an editor inside the panel, `⌘S` saves, `Esc` cancels. The card keeps
  its position, pin and source; formatting is dropped; a rewrite that
  reads as a web address becomes a link.
- Deletions, clears, per-application deletions and edits can be undone:
  `⌘Z`, the vim `u` or "Undo Last Change" in the menu bar, twenty steps
  deep within a session.

## [0.9.0] - 2026-09-14

### Added
- The search bar understands the `pinned` word, alongside `app:` and
  `type:`, as the README had promised.
- Cards and chips speak for themselves under VoiceOver: source, kind and
  a one-line summary for the label; pin, paste-stack rank and age for the
  value; paste, pin and delete as actions.
- Reduce Motion turns every fade and zoom into a cut; Reduce Transparency
  puts the frosted surfaces on a solid background and drops the blur veil.
- The left and right arrows mirror in right-to-left layouts.
- `WHISK_DATA_DIR` in the environment points Whisk at another data
  directory, so a build under test runs beside an installed copy without
  touching its history.

### Changed
- Item and character counts follow each language's plural rules.
- Retention runs when the oldest item can actually expire instead of four
  times a second, and a capacity change alone no longer rewrites the
  whole store.
- A save prepares its insert once and drops orphans with a subquery;
  500 items save in about 1.2 ms instead of 2.1 ms.
- The chip row and the rail are computed once per refresh, and thumbnail
  and preview caches are bounded.

### Fixed
- The history loaded at the default capacity of 500 whatever Settings
  said: with 1000 or Unlimited, everything past 500 was evicted at launch
  and the first save made the loss permanent.
- A history database that would not open or would not load quit the app;
  it is now set aside for inspection, a fresh one takes its place, and
  as a last resort the session runs in memory.
- A load interrupted by an error returned a shorter history as if it were
  whole; it now reports the error.
- The legacy JSON import renamed `history.json` even when the import had
  failed, stranding the history; it retires the file only once the import
  is stored, merges behind what the database holds, and sweeps `blobs/`.
- Six or eight letters from a to f — "facade", "decade" — were shown as
  color swatches; a bare hex color now needs at least one digit.
- A save no longer fails at once when another process holds the database;
  it waits up to two seconds.
- The update check told a rate-limited or offline reply apart from
  "up to date" only by luck; refusals are now logged.
- Key bindings and excluded apps that failed to save or load did so in
  silence; both now report.
- "Nothing selected", the overflow count of the preview and the
  launch-at-login error were shown in English under a French system.

## [0.8.5] - 2026-09-08

### Changed
- The app icon goes full-bleed cream, in the Tahoe style.

## [0.8.4] - 2026-09-08

### Changed
- Settings are laid out like iOS Settings: symbol tiles, grouped sections.

## [0.8.3] - 2026-09-04

### Changed
- The matcha bowl becomes the app icon, cup filling its frame within
  Apple's grid margin.

## [0.8.2] - 2026-09-03

### Changed
- The pointer says what things do: a hand over cards, a link pointer over
  chips and buttons.

## [0.8.1] - 2026-09-03

### Changed
- The Homebrew cask bumps itself on every release.

## [0.8.0] - 2026-09-03

### Added
- Search goes fuzzy, fzf-style: characters match in order, tight and
  word-anchored matches rank first.

## [0.7.19] - 2026-09-03

### Changed
- Smaller cards, one cursor at a time, no glow.

## [0.7.18] - 2026-09-03

### Changed
- Matcha becomes the accent color; the search capsule lights up as it
  stretches.

## [0.7.17] - 2026-09-03

### Added
- A pure-blur veil settles behind the panel, eased to a 3 px blur.

## [0.7.16] - 2026-09-03

### Fixed
- Every hint shows the actual binding, not the default.

## [0.7.15] - 2026-09-03

### Added
- Vim navigation, opt-in and fully rebindable: `h j k l`, `gg`, `G`, `p`,
  `P`, `v`, `m`, `f`, `dd`, `s`, `c`, `q`.

### Fixed
- Deleting the selection keeps the cursor in place.

## [0.7.14] - 2026-09-03

### Added
- Dragging a card fades the panel out of the way and lets the drop land
  behind it.

## [0.7.13] - 2026-09-03

### Changed
- Cards and app chips wear their app's color again.

## [0.7.11] - 2026-09-02

### Added
- Facets narrow both ways: selecting a kind hides the apps that never
  produced it, and selecting an app hides the kinds it never yielded.

### Fixed
- The chip cursor follows its chip, not its index, when the row reshapes.

## [0.7.10] - 2026-09-02

### Fixed
- The selection zoom scales everything, glass included.

## [0.7.9] - 2026-09-02

### Added
- Real frosted glass: a tunable gaussian blur behind every surface, on
  theme-pinned, square cards anchored at the bottom.

## [0.7.8] - 2026-09-02

### Added
- A soft blur veil quiets whatever sits behind the panel.

### Changed
- Bigger chips and card titles; app chips wear stylized app icons.

## [0.7.7] - 2026-09-02

### Changed
- Search keystrokes coalesce: one filter pass per typing burst.

## [0.7.6] - 2026-09-02

### Changed
- The app icon is the landing page's matcha bowl.
- Release builds are signed with a Developer ID and notarized when the
  secrets exist.

## [0.7.5] - 2026-09-02

### Fixed
- Every close rewinds the rail to its leading edge, so the next open
  starts at the first card.

## [0.7.4] - 2026-09-02

### Changed
- The rail is unbounded: the whole filtered history rides it, with glass
  only near the viewport.

## [0.7.3] - 2026-09-02

### Fixed
- A sluggish, glitchy close.

## [0.7.2] - 2026-09-02

### Changed
- The panel opens in under 30 ms: cards mount progressively; closing
  commits instantly.

## [0.7.1] - 2026-09-01

### Changed
- Text fills the card and melts out at the bottom; the footer counts
  characters.

### Fixed
- Images stay inside their card; screenshots credit the real app instead
  of the capture HUD.

## [0.7.0] - 2026-09-01

### Added
- Colors in every common notation — hex, `rgb()`, `hsl()`, `hsv()` — not
  just 6-digit hex.
- Multi-select filters with adaptive facets; the pinned chip leads the
  row.

### Changed
- The empty state floats as a compact pill, tinted like the glass.

### Fixed
- The selection follows the pointer on the first movement inside a card,
  and hover steals the selection only when the pointer actually moved.
- Facet pruning flows one way: apps drive categories.

## [0.6.1] - 2026-09-01

### Added
- Paste stack: `⇧⏎` toggles a card in and out of the queue; queued cards
  wear their rank.

### Fixed
- Pop-paste fires the instant the global shortcut is pressed, and the
  preview never outlives the panel.

## [0.6.0] - 2026-09-01

### Added
- Search understands `app:` and `type:` operators and matches source
  application names.
- Pause capture from the menu bar; exclude applications in Settings.
- First-run onboarding and a launch-time update check.
- Rich text travels with copies; `⌥⏎` pastes plain.
- Drag cards into any app; `⌘Y` previews the selection.
- Paste stack: queue cards, pop them anywhere with a global shortcut.
- The interface is localized in French.

### Changed
- History moves to SQLite with incremental persistence, through the
  system library; the JSON history is imported on first launch.
- Homebrew distribution switches to a cask installing the prebuilt app.

### Fixed
- Global shortcuts: each hot key claims only its own events.

## [0.5.0] - 2026-09-01

### Added
- One chip row with a separator; `⌃⇥` switches groups and is rebindable.

### Changed
- Relicensed to GPL-3.0-or-later going forward; releases up to 0.4.0
  remain MIT.

## [0.4.0] - 2026-09-01

### Added
- Launch at login, `⌘1`…`⌘9` direct paste, a pinned filter chip and
  retention settings, including an unlimited capacity option.

### Changed
- Per-item work is memoized: navigation stops re-running regexes.

### Fixed
- `⌘digits` follow the typed character only, so shifted-digit layouts
  use their real digit keys.

## [0.3.0] - 2026-09-01

### Added
- A Settings window with rebindable keyboard shortcuts.
- A DMG ships with every release.

### Fixed
- A recorded shortcut applies immediately, not one change behind.

## [0.2.1] - 2026-08-31

### Fixed
- The SwiftPM resource bundle ships inside the app.

## [0.2.0] - 2026-08-31

### Added
- Filter the rail by source application and content category, with
  keyboard zones and category icons.

### Changed
- Chips sit above the search field; the panel floats over the Dock.

## [0.1.3] - 2026-08-31

### Added
- Hovering highlights a card; the selection zoom returns.

### Changed
- Full-width rail with in-content margins.

## [0.1.2] - 2026-08-31

### Changed
- Eager, bounded rail so fast scrolling never pops cards in.

### Fixed
- The glass layer stays static so selection moves stop flashing.

## [0.1.1] - 2026-08-31

### Fixed
- Homebrew builds run without SwiftPM's sandbox.

## [0.1.0] - 2026-08-31

### Added
- Clipboard history in a menu bar app: text, links, images and files,
  captured with the source application's identity.
- A Liquid Glass panel with per-source-app card styling, arrow-key
  navigation and Return to paste.
- Rich previews and syntax highlighting.
- The hot key and the synthetic paste follow the keyboard layout.

[Unreleased]: https://github.com/nathan-poncet/whisk/compare/v0.10.0...HEAD
[0.10.0]: https://github.com/nathan-poncet/whisk/compare/v0.9.0...v0.10.0
[0.9.0]: https://github.com/nathan-poncet/whisk/compare/v0.8.5...v0.9.0
[0.8.5]: https://github.com/nathan-poncet/whisk/compare/v0.8.4...v0.8.5
[0.8.4]: https://github.com/nathan-poncet/whisk/compare/v0.8.3...v0.8.4
[0.8.3]: https://github.com/nathan-poncet/whisk/compare/v0.8.2...v0.8.3
[0.8.2]: https://github.com/nathan-poncet/whisk/compare/v0.8.1...v0.8.2
[0.8.1]: https://github.com/nathan-poncet/whisk/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/nathan-poncet/whisk/compare/v0.7.19...v0.8.0
[0.7.19]: https://github.com/nathan-poncet/whisk/compare/v0.7.18...v0.7.19
[0.7.18]: https://github.com/nathan-poncet/whisk/compare/v0.7.17...v0.7.18
[0.7.17]: https://github.com/nathan-poncet/whisk/compare/v0.7.16...v0.7.17
[0.7.16]: https://github.com/nathan-poncet/whisk/compare/v0.7.15...v0.7.16
[0.7.15]: https://github.com/nathan-poncet/whisk/compare/v0.7.14...v0.7.15
[0.7.14]: https://github.com/nathan-poncet/whisk/compare/v0.7.13...v0.7.14
[0.7.13]: https://github.com/nathan-poncet/whisk/compare/v0.7.12...v0.7.13
[0.7.11]: https://github.com/nathan-poncet/whisk/compare/v0.7.10...v0.7.11
[0.7.10]: https://github.com/nathan-poncet/whisk/compare/v0.7.9...v0.7.10
[0.7.9]: https://github.com/nathan-poncet/whisk/compare/v0.7.8...v0.7.9
[0.7.8]: https://github.com/nathan-poncet/whisk/compare/v0.7.7...v0.7.8
[0.7.7]: https://github.com/nathan-poncet/whisk/compare/v0.7.6...v0.7.7
[0.7.6]: https://github.com/nathan-poncet/whisk/compare/v0.7.5...v0.7.6
[0.7.5]: https://github.com/nathan-poncet/whisk/compare/v0.7.4...v0.7.5
[0.7.4]: https://github.com/nathan-poncet/whisk/compare/v0.7.3...v0.7.4
[0.7.3]: https://github.com/nathan-poncet/whisk/compare/v0.7.2...v0.7.3
[0.7.2]: https://github.com/nathan-poncet/whisk/compare/v0.7.1...v0.7.2
[0.7.1]: https://github.com/nathan-poncet/whisk/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/nathan-poncet/whisk/compare/v0.6.1...v0.7.0
[0.6.1]: https://github.com/nathan-poncet/whisk/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/nathan-poncet/whisk/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/nathan-poncet/whisk/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/nathan-poncet/whisk/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/nathan-poncet/whisk/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/nathan-poncet/whisk/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/nathan-poncet/whisk/compare/v0.1.3...v0.2.0
[0.1.3]: https://github.com/nathan-poncet/whisk/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/nathan-poncet/whisk/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/nathan-poncet/whisk/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/nathan-poncet/whisk/releases/tag/v0.1.0
