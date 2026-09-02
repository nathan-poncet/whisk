import SwiftUI

/// The card indices the scroll position keeps on screen, quantized to
/// whole cards so state only changes when the leading card does.
private struct RailWindow: Equatable {
    var leading = 0
    var capacity = 8
}

struct HistoryPanelView: View {
    @ObservedObject var store: HistoryViewStateStore
    let actions: PanelActions
    @FocusState private var searchFocused: Bool

    /// The render server pays ~8 ms per glass layer whenever the panel
    /// orders on or off screen, so only the cards inside the viewport plus
    /// a delta on each side are displayed at all; the slots beyond keep
    /// their size but render nothing, and everything is preloaded so a
    /// card entering the delta arrives fully formed.
    @State private var railWindow = RailWindow()
    private static let cardStride: CGFloat = 244
    private static let mountDelta = 8

    /// The field echoes keystrokes instantly; the controller's query only
    /// follows after the debounce, so the text must live here.
    @State private var searchText = ""

    private var queryBinding: Binding<String> {
        Binding(
            get: { searchText },
            set: { newValue in
                searchText = newValue
                actions.search(newValue)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // The landing page's layout, mirrored: a centered search capsule
            // of bounded width, the filter chips centered right below it.
            toolbar
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
            if !store.state.filters.isEmpty {
                FilterBarView(
                    filters: store.state.filters,
                    onToggleApp: actions.toggleSourceFilter,
                    onToggleKind: actions.toggleCategoryFilter,
                    onFocusApp: actions.focusSourceChip,
                    onFocusKind: actions.focusCategoryChip
                )
            }
            content
        }
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onChange(of: store.focusRevision) {
            searchFocused = true
            searchText = store.state.query
        }
        .onAppear {
            ItemCardView.prewarm(store.state.cards)
        }
        .onChange(of: store.state.cards) { _, cards in
            ItemCardView.prewarm(cards)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(localized("Search clipboard history"), text: queryBinding)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            Spacer()
            if store.state.stackCount > 0 {
                Label("\(store.state.stackCount)", systemImage: "square.stack.3d.up.fill")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.accentColor)
                    .help(localized("Paste stack — pop with the global shortcut"))
            }
            Text(store.state.countLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .liquidGlass(in: Capsule())
    }

    @ViewBuilder private var content: some View {
        if store.state.cards.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                rail
                    // The rail spans the full screen width; margins live
                    // inside the scroll content so cards travel all the way
                    // to the edges, and the clip is lifted so the selection
                    // halo and zoom are never shaved off.
                    .contentMargins(.horizontal, 16, for: .scrollContent)
                    .scrollClipDisabled()
                    .onChange(of: store.state.selectedID) { _, selectedID in
                        guard let selectedID else { return }
                        // No anchor: scroll the minimum needed to reveal the
                        // card instead of recentring on every key press.
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(selectedID)
                        }
                    }
                    .onChange(of: store.closeRevision) {
                        // Rewind while hidden: the next open starts at zero,
                        // never showing the carousel travel back.
                        guard let first = store.state.cards.first?.id else { return }
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            proxy.scrollTo(first, anchor: .leading)
                        }
                    }
            }
        }
    }

    @ViewBuilder private var rail: some View {
        let scrollView = ScrollView(.horizontal, showsIndicators: false) {
            // Eager sizing on purpose: a lazy stack materializes cards at
            // the viewport's edge, which pops them in during fast scrolls.
            // Every slot is laid out; only the windowed ones carry glass.
            HStack(spacing: 14) {
                let selectedIndex = store.state.cards.firstIndex { $0.id == store.state.selectedID }
                ForEach(Array(store.state.cards.enumerated()), id: \.element.id) { index, card in
                    Group {
                        if isMounted(index, selectedIndex: selectedIndex) {
                            ItemCardView(
                                card: card,
                                onSelect: { actions.select(card.id) },
                                onHighlight: { actions.highlight(card.id) },
                                onTogglePin: { actions.togglePin(card.id) },
                                onDelete: { actions.delete(card.id) }
                            )
                            .equatable()
                        } else {
                            railPlaceholder
                        }
                    }
                    .id(card.id)
                }
            }
            .padding(.vertical, 8)
        }
        if #available(macOS 15.0, *) {
            scrollView
                .onScrollGeometryChange(for: RailWindow.self) { geometry in
                    RailWindow(
                        leading: max(0, Int(geometry.contentOffset.x / Self.cardStride)),
                        capacity: Int(geometry.containerSize.width / Self.cardStride) + 1
                    )
                } action: { _, window in
                    railWindow = window
                }
        } else {
            scrollView
        }
    }

    private func isMounted(_ index: Int, selectedIndex: Int?) -> Bool {
        // Without scroll geometry (macOS 14) every slot mounts, as before.
        guard #available(macOS 15.0, *) else { return true }
        if index == selectedIndex { return true }
        let lower = max(0, railWindow.leading - Self.mountDelta)
        let upper = railWindow.leading + railWindow.capacity + Self.mountDelta
        return (lower...upper).contains(index)
    }

    // Off-window slots display nothing at all — they only hold the scroll
    // extent steady.
    private var railPlaceholder: some View {
        Color.clear
            .frame(width: 230, height: 230)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary)
            Text(
                store.state.query.isEmpty && !store.state.filters.hasActiveChip
                    ? localized("Copy something to get started")
                    : localized("No matches")
            )
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous), cornerRadius: 22)
        .padding(.horizontal, 16)
    }
}
