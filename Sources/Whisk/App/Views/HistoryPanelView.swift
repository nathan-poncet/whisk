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
    /// orders on or off screen, so only the cards near the viewport carry
    /// glass; the rest are same-sized cheap placeholders swapped in as the
    /// user scrolls (a sliding window, margin included).
    @State private var railWindow = RailWindow()
    private static let cardStride: CGFloat = 244
    private static let mountMargin = 4

    private var queryBinding: Binding<String> {
        Binding(
            get: { store.state.query },
            set: { actions.search($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !store.state.filters.isEmpty {
                FilterBarView(
                    filters: store.state.filters,
                    onToggleApp: actions.toggleSourceFilter,
                    onToggleKind: actions.toggleCategoryFilter,
                    onFocusApp: actions.focusSourceChip,
                    onFocusKind: actions.focusCategoryChip
                )
            }
            toolbar
                .padding(.horizontal, 16)
            content
        }
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: store.focusRevision) {
            searchFocused = true
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
                if store.state.hiddenCount > 0 {
                    overflowCard
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
        let lower = max(0, railWindow.leading - Self.mountMargin)
        let upper = railWindow.leading + railWindow.capacity + Self.mountMargin
        return (lower...upper).contains(index)
    }

    private var railPlaceholder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
            .frame(width: 230)
            .frame(maxHeight: .infinity)
    }

    private var overflowCard: some View {
        VStack(spacing: 6) {
            Text("+\(store.state.hiddenCount)")
                .font(.title3.weight(.semibold))
            Text(localized("older items\nsearch to find them"))
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120)
        .frame(maxHeight: .infinity)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
    }
}
