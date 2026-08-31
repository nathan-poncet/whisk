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
        GlassGroup {
            VStack(alignment: .leading, spacing: 14) {
                toolbar
                content
            }
        }
        .padding(.horizontal, 16)
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
                .onSubmit {
                    actions.selectFirst()
                }
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
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(store.state.cards) { card in
                        ItemCardView(
                            card: card,
                            onSelect: { actions.select(card.id) },
                            onTogglePin: { actions.togglePin(card.id) },
                            onDelete: { actions.delete(card.id) }
                        )
                    }
                }
                .padding(4)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary)
            Text(store.state.query.isEmpty ? "Copy something to get started" : "No matches")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
