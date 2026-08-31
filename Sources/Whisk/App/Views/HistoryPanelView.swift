import SwiftUI

struct HistoryPanelView: View {
    @ObservedObject var store: HistoryViewStateStore
    let actions: PanelActions
    @FocusState private var searchFocused: Bool

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
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: store.focusRevision) {
            searchFocused = true
        }
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard history", text: queryBinding)
                .textFieldStyle(.plain)
                .focused($searchFocused)
            Spacer()
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
                ScrollView(.horizontal, showsIndicators: false) {
                    // Eager on purpose: a lazy stack materializes cards at
                    // the viewport's edge, which pops them in during fast
                    // scrolls. The controller bounds the rail instead.
                    HStack(spacing: 14) {
                        ForEach(store.state.cards) { card in
                            ItemCardView(
                                card: card,
                                onSelect: { actions.select(card.id) },
                                onHighlight: { actions.highlight(card.id) },
                                onTogglePin: { actions.togglePin(card.id) },
                                onDelete: { actions.delete(card.id) }
                            )
                            .equatable()
                            .id(card.id)
                        }
                        if store.state.hiddenCount > 0 {
                            overflowCard
                        }
                    }
                    .padding(.vertical, 8)
                }
                // The rail spans the full screen width; margins live inside
                // the scroll content so cards travel all the way to the
                // edges, and the clip is lifted so the selection halo and
                // zoom are never shaved off.
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

    private var overflowCard: some View {
        VStack(spacing: 6) {
            Text("+\(store.state.hiddenCount)")
                .font(.title3.weight(.semibold))
            Text("older items\nsearch to find them")
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
                    ? "Copy something to get started"
                    : "No matches"
            )
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 16)
    }
}
