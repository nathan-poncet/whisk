import SwiftUI

struct HistoryPanelView: View {
    @ObservedObject var store: HistoryViewStateStore
    let actions: PanelActions
    @FocusState private var searchFocused: Bool

    /// Every glass card costs several milliseconds to rasterize when the
    /// panel appears; mounting all sixty up front made ⇧⌘V feel sluggish.
    /// The panel opens with a screenful and the rest mounts in small
    /// batches between run-loop turns, while the user can already type.
    @State private var mountedCards = HistoryPanelView.initialBatch
    /// Bumped on every open and close: in-flight batch steps from the
    /// previous phase compare against it and cancel themselves.
    @State private var railGeneration = 0
    private static let initialBatch = 14
    private static let batchStep = 10

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
            railGeneration += 1
            mountNextBatch(generation: railGeneration)
        }
        .onChange(of: store.closeRevision) {
            railGeneration += 1
            unmountNextBatch(generation: railGeneration)
        }
        .onChange(of: store.state.cards.count) {
            mountNextBatch(generation: railGeneration)
        }
        .onChange(of: store.state.selectedID) { _, selectedID in
            // Keyboard navigation may outrun the mounting: reveal up to the
            // selection immediately.
            guard let selectedID,
                let index = store.state.cards.firstIndex(where: { $0.id == selectedID }),
                index >= mountedCards
            else { return }
            mountedCards = index + Self.batchStep
        }
    }

    private func mountNextBatch(generation: Int) {
        guard generation == railGeneration, mountedCards < store.state.cards.count else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            guard generation == railGeneration, mountedCards < store.state.cards.count else { return }
            mountedCards = min(mountedCards + Self.batchStep, store.state.cards.count)
            mountNextBatch(generation: generation)
        }
    }

    /// Tearing all the cards down at once would stall the close: the first
    /// step waits for the window's disappearance to commit, then the rail
    /// shrinks batch by batch while nobody can see it.
    private func unmountNextBatch(generation: Int) {
        guard generation == railGeneration, mountedCards > Self.initialBatch else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard generation == railGeneration, mountedCards > Self.initialBatch else { return }
            mountedCards = max(mountedCards - Self.batchStep, Self.initialBatch)
            unmountNextBatch(generation: generation)
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
                ScrollView(.horizontal, showsIndicators: false) {
                    // Eager on purpose: a lazy stack materializes cards at
                    // the viewport's edge, which pops them in during fast
                    // scrolls. The controller bounds the rail instead.
                    HStack(spacing: 14) {
                        ForEach(store.state.cards.prefix(mountedCards)) { card in
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
