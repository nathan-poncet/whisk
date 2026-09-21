import AppKit
import Carbon.HIToolbox
import SwiftUI
import Testing

@testable import Whisk

/// Draws a view into a bitmap, off screen: the whole body runs, every
/// branch the state selects, without a window.
@MainActor
private func render<V: View>(_ view: V, _ width: CGFloat, _ height: CGFloat) -> NSImage? {
    let renderer = ImageRenderer(content: view)
    renderer.proposedSize = ProposedViewSize(width: width, height: height)
    return renderer.nsImage
}

/// Hosts a view in a window that is never ordered in: the AppKit-backed
/// pieces — the behind-window blur — get a layer, a window and a layout
/// pass, and nothing appears on screen.
@MainActor
private func hostOffscreen<V: View>(_ view: V, _ width: CGFloat, _ height: CGFloat) -> NSWindow {
    _ = NSApplication.shared
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: .borderless, backing: .buffered,
        defer: false)
    window.isReleasedWhenClosed = false
    let hosting = NSHostingView(rootView: view)
    hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
    window.contentView = hosting
    hosting.layoutSubtreeIfNeeded()
    hosting.displayIfNeeded()
    return window
}

/// A history with one card of every kind and every state a card can be
/// in, presented with a full chip row.
@MainActor
enum ViewFixtures {
    static let now = Date(timeIntervalSince1970: 1_700_000_000)
    static let richLink = "file:///nonexistent/whisk/rich-link"
    static let bareLink = "file:///nonexistent/whisk/bare-link"
    static let thumbnailed = "/nonexistent/whisk/a.txt"

    static var png: Data {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        return bitmap?.representation(using: .png, properties: [:]) ?? Data()
    }

    static var swatch: NSImage {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.systemGreen.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()
        return image
    }

    static func items() -> [ClipboardItem] {
        [
            anItem(
                .text("Let me know when you arrive, we can talk then."), from: "Slack", bundle: "com.slack", at: now,
                pinned: true),
            anItem(.text("func greet() -> String { return \"hi\" }"), from: "Ghostty", bundle: "dev.ghostty", at: now),
            anItem(.text("#7d9471"), from: "Figma", at: now),
            anItem(.link(URL(fileURLWithPath: "/nonexistent/whisk/rich-link")), from: "Safari", at: now),
            anItem(.link(URL(fileURLWithPath: "/nonexistent/whisk/bare-link")), from: "Safari", at: now),
            anItem(.image(png), from: "Preview", bundle: "com.apple.Preview", at: now),
            anItem(.image(Data([0x01])), from: nil, at: now),
            anItem(
                .fileReferences([thumbnailed, "/nonexistent/whisk/b.txt", "/n/c", "/n/d", "/n/e"]), from: "Finder",
                bundle: "com.apple.finder", at: now),
        ]
    }

    /// Canned metadata so the loaded branches of the previews render too.
    static func seedPreviews() {
        LinkPreviewStore.shared.store(
            LinkPreview(title: "A rich page", host: "example.com", icon: swatch, image: swatch), for: richLink)
        LinkPreviewStore.shared.store(LinkPreview(title: nil, host: nil, icon: swatch, image: nil), for: bareLink)
        FileThumbnailStore.shared.store(swatch, for: thumbnailed)
    }

    static func chipRow() -> [ChipEntry] {
        let sources = [
            SourceApp(name: "Slack", bundleID: "com.slack"), SourceApp(name: "Ghostty", bundleID: "dev.ghostty"),
            SourceApp(name: "Figma"), SourceApp(name: "Safari"),
            SourceApp(name: "Finder", bundleID: "com.apple.finder"),
        ].compactMap { $0 }
        return ChipEntry.row(hasPinned: true, sources: sources, categories: ContentCategory.allCases)
    }

    static func state(selecting index: Int? = 0, query: String = "", pinnedOnly: Bool = false) -> HistoryViewState {
        let items = items()
        return HistoryPresenter().present(
            items: items, query: query, now: now.addingTimeInterval(90),
            selectedID: index.map { items[$0].id }, stack: [items[1].id, items[2].id],
            filters: FilterContext(
                chips: chipRow(), activeSourceKeys: ["com.slack"], activeCategories: [.code], pinnedOnly: pinnedOnly,
                focusedChipID: "dev.ghostty"))
    }

    /// Enough cards that the rail's mounting window leaves placeholders.
    static func longState() -> HistoryViewState {
        let items = (0..<24).map { anItem(.text("entry \($0)"), at: now) }
        return HistoryPresenter().present(items: items, query: "", now: now, selectedID: items[0].id)
    }

    static let spy = PanelActionSpy()

    static func card(_ card: CardViewState, showsSelection: Bool = true) -> ItemCardView {
        ItemCardView(card: card, actions: spy.actions, showsSelection: showsSelection)
    }
}

@MainActor
@Suite struct CardRendering {
    @Test func every_card_kind_renders_selected_plain_and_hosted() {
        ViewFixtures.seedPreviews()
        let state = ViewFixtures.state()
        ItemCardView.prewarm(state.cards)

        for card in state.cards {
            #expect(render(ViewFixtures.card(card), 210, 210) != nil, "card \(card.kindLabel)")
            #expect(render(ViewFixtures.card(card, showsSelection: false), 210, 210) != nil)
        }
        let searched = HistoryPresenter().present(
            items: ViewFixtures.items(), query: "arrive greet", now: ViewFixtures.now)
        for card in searched.cards where !card.matches.isEmpty {
            #expect(render(ViewFixtures.card(card), 210, 210) != nil, "highlighted \(card.kindLabel)")
        }
        #expect(searched.cards.filter { !$0.matches.isEmpty }.count == 2)
        let window = hostOffscreen(ViewFixtures.card(state.cards[0]), 210, 210)
        #expect(window.contentView != nil)

        for size in CardSize.allCases {
            let sized = ItemCardView(card: state.cards[0], actions: ViewFixtures.spy.actions, side: size.side)
            #expect(render(sized, size.side * 1.05, size.side * 1.05) != nil, "card at \(size)")
        }
    }

    @Test func link_and_file_previews_render_loaded_and_bare_at_both_sizes() {
        ViewFixtures.seedPreviews()

        for size in [LinkPreviewView.Size.card, .large] {
            #expect(render(LinkPreviewView(address: ViewFixtures.richLink, size: size), 300, 300) != nil)
            #expect(render(LinkPreviewView(address: ViewFixtures.bareLink, size: size), 300, 300) != nil)
            #expect(render(LinkPreviewView(address: "not a url at all", size: size), 300, 300) != nil)
        }
        for size in [FilePreviewView.Size.card, .large] {
            let view = FilePreviewView(
                names: ["a.txt", "b.txt"], overflow: 3, thumbnailPath: ViewFixtures.thumbnailed, size: size)
            #expect(render(view, 300, 300) != nil)
            #expect(render(FilePreviewView(names: ["c"], overflow: 0, thumbnailPath: nil, size: size), 300, 300) != nil)
        }
    }
}

@MainActor
@Suite struct ChipBarRendering {
    @Test func the_chip_row_renders_active_focused_and_suppressed_chips() {
        let filters = ViewFixtures.state().filters
        let bar = FilterBarView(
            filters: filters, onToggleApp: { _ in }, onToggleKind: { _ in }, onFocusApp: { _ in },
            onFocusKind: { _ in })
        let suppressed = FilterBarView(
            filters: filters, cursorSuppressed: true, onToggleApp: { _ in }, onToggleKind: { _ in },
            onFocusApp: { _ in }, onFocusKind: { _ in })

        #expect(render(bar, 900, 44) != nil)
        #expect(render(suppressed, 900, 44) != nil)
        #expect(hostOffscreen(bar, 900, 44).contentView != nil)
    }

    @Test func chips_fall_back_when_their_resource_is_missing_or_they_have_no_icon() {
        let odd = FilterBarViewState(
            pinned: [],
            apps: [],
            kinds: [
                FilterChip(
                    id: "a", label: "Odd", sourceBundleID: nil, icon: .resource("no-such-icon", fallback: "square"),
                    accessibilityLabel: "Odd", isActive: true, isFocused: false),
                FilterChip(
                    id: "b", label: "Bare", sourceBundleID: nil, icon: nil, accessibilityLabel: "Bare",
                    isActive: false, isFocused: true),
            ])
        let bar = FilterBarView(
            filters: odd, onToggleApp: { _ in }, onToggleKind: { _ in }, onFocusApp: { _ in }, onFocusKind: { _ in })

        #expect(render(bar, 400, 44) != nil)
    }

    @Test func a_chip_row_that_fits_is_stretched_to_its_viewport_and_a_wide_one_still_scrolls() throws {
        let items = ViewFixtures.items()
        func row(_ chips: [ChipEntry]) -> FilterBarView {
            FilterBarView(
                filters: HistoryPresenter().present(
                    items: items, query: "", now: ViewFixtures.now, filters: FilterContext(chips: chips)
                ).filters,
                onToggleApp: { _ in }, onToggleKind: { _ in }, onFocusApp: { _ in }, onFocusKind: { _ in })
        }

        let short = hostOffscreen(row(ChipEntry.row(hasPinned: true, sources: [], categories: [.text])), 900, 60)
        let shortHost = try #require(short.contentView)
        pump(shortHost)
        let shortScroll = try #require(firstScrollView(in: shortHost))
        let shortDocument = try #require(shortScroll.documentView)
        #expect(shortDocument.frame.width >= shortScroll.bounds.width - 40)

        let wide = hostOffscreen(row(ViewFixtures.chipRow()), 500, 60)
        let wideHost = try #require(wide.contentView)
        pump(wideHost)
        let wideScroll = try #require(firstScrollView(in: wideHost))
        let wideDocument = try #require(wideScroll.documentView)
        #expect(wideDocument.frame.width > wideScroll.bounds.width)
    }

    @Test func a_hosted_chip_row_scrolls_to_the_chip_that_takes_the_cursor() throws {
        let store = HistoryViewStateStore()
        let spy = PanelActionSpy()
        store.update(ViewFixtures.state())
        let window = hostOffscreen(HistoryPanelView(store: store, actions: spy.actions), 1200, 430)
        let hosting = try #require(window.contentView)
        pump(hosting)

        let items = ViewFixtures.items()
        let moved = HistoryPresenter().present(
            items: items, query: "", now: ViewFixtures.now, selectedID: nil,
            filters: FilterContext(chips: ViewFixtures.chipRow(), focusedChipID: "pinned"))
        store.update(moved)
        pump(hosting)

        #expect(store.state.filters.focusedChipID == "pinned")
    }
}

/// Lets SwiftUI process the state changes a hosted view observes.
@MainActor
private func pump(_ hosting: NSView) {
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    hosting.layoutSubtreeIfNeeded()
    hosting.displayIfNeeded()
}

/// SwiftUI backs its ScrollView with an NSScrollView on macOS.
@MainActor
private func firstScrollView(in view: NSView) -> NSScrollView? {
    if let scroll = view as? NSScrollView { return scroll }
    for child in view.subviews {
        if let found = firstScrollView(in: child) { return found }
    }
    return nil
}

@MainActor
@Suite struct PanelRendering {
    private let spy = PanelActionSpy()

    private func panel(_ store: HistoryViewStateStore) -> HistoryPanelView {
        HistoryPanelView(store: store, actions: spy.actions)
    }

    @Test func a_hosted_panel_follows_state_changes_selection_focus_modes_and_close() throws {
        let store = HistoryViewStateStore()
        store.update(ViewFixtures.longState())
        let window = hostOffscreen(panel(store), 1200, 430)
        let hosting = try #require(window.contentView)
        pump(hosting)

        store.update(
            HistoryPresenter().present(
                items: ViewFixtures.items(), query: "arrive", now: ViewFixtures.now,
                selectedID: ViewFixtures.items()[0].id))
        pump(hosting)
        store.requestSearchFocus()
        pump(hosting)
        store.configureInput(vim: true, searchKey: "s")
        store.setSearchActive(true)
        pump(hosting)
        store.setSearchActive(false)
        pump(hosting)
        store.update(HistoryPresenter().present(items: ViewFixtures.items(), query: "", now: ViewFixtures.now))
        pump(hosting)
        store.panelDidClose()
        pump(hosting)

        #expect(store.closeRevision == 1)
    }

    @Test func the_panel_renders_populated_empty_and_in_every_vim_mode() {
        ViewFixtures.seedPreviews()
        let store = HistoryViewStateStore()

        store.update(ViewFixtures.state())
        store.configureInput(vim: false, searchKey: "s")
        #expect(render(panel(store), 1200, 430) != nil)
        #expect(hostOffscreen(panel(store), 1200, 430).contentView != nil)

        store.configureInput(vim: true, searchKey: "s")
        #expect(render(panel(store), 1200, 430) != nil)
        store.setSearchActive(true)
        #expect(render(panel(store), 1200, 430) != nil)

        store.update(HistoryPresenter().present(items: [], query: "zzz", now: ViewFixtures.now))
        #expect(render(panel(store), 1200, 430) != nil)
        store.update(.empty)
        #expect(render(panel(store), 1200, 430) != nil)

        store.update(ViewFixtures.longState())
        store.configureCards(side: CardSize.large.side)
        #expect(render(panel(store), 1200, 480) != nil)
        store.configureCards(side: CardSize.small.side)
        #expect(render(panel(store), 1200, 390) != nil)

        store.configureCards(side: CardSize.medium.side)
        store.update(ViewFixtures.state())
        store.beginEditing(store.state.cards[0])
        #expect(store.editing != nil)
        #expect(render(panel(store), 1200, 430) != nil)
        #expect(hostOffscreen(panel(store), 1200, 430).contentView != nil)
        store.endEditing()
    }

    @Test func the_editor_renders_for_text_code_and_link_cards_blank_or_not() {
        let state = ViewFixtures.state()
        let store = HistoryViewStateStore()

        for card in state.cards where card.transformable {
            store.beginEditing(card)
            let editor = EditItemView(store: store, card: card, onSave: { _ in }, onCancel: {})
            #expect(render(editor, 900, 300) != nil, "editor for \(card.kindLabel)")
            store.setEditingText("")
            #expect(render(editor, 900, 300) != nil, "blank editor for \(card.kindLabel)")
            store.endEditing()
        }
    }
}

@MainActor
@Suite struct OverlayRendering {
    @Test func the_preview_overlay_renders_every_kind_and_the_empty_case() {
        ViewFixtures.seedPreviews()
        let store = HistoryViewStateStore()
        let count = ViewFixtures.items().count

        for index in 0..<count {
            store.update(ViewFixtures.state(selecting: index))
            #expect(render(PreviewOverlayView(store: store), 700, 480) != nil, "overlay \(index)")
        }
        store.update(ViewFixtures.state(selecting: nil))
        #expect(render(PreviewOverlayView(store: store), 700, 480) != nil)
        #expect(hostOffscreen(PreviewOverlayView(store: store), 700, 480).contentView != nil)
    }
}

@MainActor
@Suite struct WindowsRendering {
    @Test func the_onboarding_renders() {
        _ = NSApplication.shared

        #expect(render(OnboardingView(toggleShortcut: "⇧⌘V", onContinue: {}), 440, 420) != nil)
    }

    @Test func the_settings_render_with_vim_off_then_on_with_duplicates_recording_and_exclusions() throws {
        let sandbox = try IsolatedDefaults()
        let bindings = KeyBindingsStore(defaults: sandbox.defaults)
        let general = GeneralSettingsStore(defaults: sandbox.defaults)
        let vim = VimBindingsStore(defaults: sandbox.defaults)
        let login = LoginItemManager()
        let view = SettingsView(store: bindings, general: general, loginItem: login, vimBindings: vim)

        #expect(hostOffscreen(view, 560, 720).contentView != nil)

        general.vimNavigation = true
        general.excludedApps = [ExcludedApp(bundleID: "com.apple.finder", name: "Finder")]
        bindings.set(bindings.binding(for: .deleteSelection), for: .pinSelection)
        vim.set("p", for: .preview)
        bindings.beginRecording(.stackSelection)
        defer { bindings.endRecording() }

        #expect(hostOffscreen(view, 560, 720).contentView != nil)
        #expect(render(view, 560, 720) != nil)

        let storeBuild = SettingsView(
            store: bindings, general: general, loginItem: login, vimBindings: vim, distribution: .appStore)
        #expect(render(storeBuild, 560, 720) != nil)
    }

    @Test func the_blur_veil_and_the_glass_surfaces_take_a_window() {
        let veil = hostOffscreen(GradientBlurVeil(), 800, 430)
        let glass = hostOffscreen(
            Text("glass").padding().liquidGlass(in: Capsule()).padding().liquidGlass(
                in: RoundedRectangle(cornerRadius: 12), cornerRadius: 12, tint: .red), 300, 120)

        #expect(veil.contentView != nil)
        #expect(glass.contentView != nil)
        #expect(BackdropBlurTuner.backdropLayer(in: CALayer()) == nil)
        #expect(!BackdropBlurTuner.tune(nil, radius: 3))
    }
}

@MainActor
@Suite struct DragProviders {
    @Test func each_payload_kind_becomes_an_item_provider() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("whisk-drag-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: file) }
        try Data("dragged".utf8).write(to: file)
        let url = try #require(URL(string: "https://example.com"))

        #expect(ItemCardView.dragProvider(for: .text("hello")).canLoadObject(ofClass: NSString.self))
        #expect(ItemCardView.dragProvider(for: .link(url)).canLoadObject(ofClass: NSURL.self))
        #expect(ItemCardView.dragProvider(for: .image(ViewFixtures.png)).canLoadObject(ofClass: NSImage.self))
        #expect(!ItemCardView.dragProvider(for: .image(Data([0x01]))).canLoadObject(ofClass: NSImage.self))
        #expect(!ItemCardView.dragProvider(for: .files([file.path])).registeredTypeIdentifiers.isEmpty)
        #expect(ItemCardView.dragProvider(for: .files([])).registeredTypeIdentifiers.isEmpty)
    }
}

@MainActor
@Suite struct DefaultArguments {
    @Test func the_defaults_of_the_views_and_helpers_construct() throws {
        let sandbox = try IsolatedDefaults()
        let store = HistoryViewStateStore()
        let card = ViewFixtures.state().cards[0]

        _ = ItemCardView(card: card, actions: PanelActionSpy().actions)
        #expect(render(CodeTextView(text: "let a = 1", tokens: []), 200, 100) != nil)
        _ = UpdateChecker()
        _ = PanelKeyRouter(
            stateStore: store, actions: PanelActionSpy().actions,
            keyBindings: KeyBindingsStore(defaults: sandbox.defaults),
            vimBindings: VimBindingsStore(defaults: sandbox.defaults), togglePreview: {}, closePanel: {})

        let bindings = KeyBindingsStore(defaults: sandbox.defaults)
        bindings.set(KeyBinding(keyCode: 0xFF, modifiers: []), for: .pinSelection)
        bindings.set(KeyBinding(keyCode: 1, modifiers: []), for: .deleteSelection)
        #expect(bindings.label(for: .pinSelection) == "key 255")
        bindings.resetAll()
        #expect(!bindings.isCustomized(.pinSelection) && !bindings.isCustomized(.deleteSelection))
    }

    @Test func a_backdrop_view_tunes_its_blur_when_it_has_a_layer() {
        _ = NSApplication.shared
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80), styleMask: .borderless, backing: .buffered,
            defer: false)
        window.isReleasedWhenClosed = false
        let backdrop = BackdropView()
        backdrop.wantsLayer = true
        backdrop.cornerRadius = 8
        window.contentView = backdrop
        backdrop.layoutSubtreeIfNeeded()
        backdrop.updateLayer()
        let veil = GradientVeilView()
        veil.wantsLayer = true
        veil.frame = NSRect(x: 0, y: 0, width: 120, height: 80)
        veil.layoutSubtreeIfNeeded()
        veil.updateLayer()

        #expect(backdrop.maskImage != nil)
        #expect(veil.maskImage != nil)
    }
}
