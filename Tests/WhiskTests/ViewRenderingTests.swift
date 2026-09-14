import AppKit
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

    static func state(selecting index: Int? = 0, query: String = "", pinnedOnly: Bool = false) -> HistoryViewState {
        let items = items()
        let sources = [
            SourceApp(name: "Slack", bundleID: "com.slack"), SourceApp(name: "Ghostty", bundleID: "dev.ghostty"),
            SourceApp(name: "Figma"), SourceApp(name: "Safari"),
        ].compactMap { $0 }
        let row = ChipEntry.row(hasPinned: true, sources: sources, categories: ContentCategory.allCases)
        return HistoryPresenter().present(
            items: items, query: query, now: now.addingTimeInterval(90),
            selectedID: index.map { items[$0].id }, stack: [items[1].id, items[2].id],
            filters: FilterContext(
                chips: row, activeSourceKeys: ["com.slack"], activeCategories: [.code], pinnedOnly: pinnedOnly,
                focusedChipID: "dev.ghostty"))
    }

    static func card(_ card: CardViewState, showsSelection: Bool = true) -> ItemCardView {
        ItemCardView(
            card: card, onSelect: {}, onHighlight: {}, onTogglePin: {}, onDelete: {}, onDragBegin: {},
            showsSelection: showsSelection)
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
        let window = hostOffscreen(ViewFixtures.card(state.cards[0]), 210, 210)
        #expect(window.contentView != nil)
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
            filters: filters, cursorSuppressed: false, onToggleApp: { _ in }, onToggleKind: { _ in },
            onFocusApp: { _ in }, onFocusKind: { _ in })
        let suppressed = FilterBarView(
            filters: filters, cursorSuppressed: true, onToggleApp: { _ in }, onToggleKind: { _ in },
            onFocusApp: { _ in }, onFocusKind: { _ in })

        #expect(render(bar, 900, 44) != nil)
        #expect(render(suppressed, 900, 44) != nil)
        #expect(hostOffscreen(bar, 900, 44).contentView != nil)
    }
}

@MainActor
@Suite struct PanelRendering {
    private func panel(_ store: HistoryViewStateStore) -> HistoryPanelView {
        HistoryPanelView(store: store, actions: PanelActionSpy().actions)
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
