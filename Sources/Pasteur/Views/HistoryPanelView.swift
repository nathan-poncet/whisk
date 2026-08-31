import PasteurKernel
import SwiftUI

struct HistoryPanelView: View {
    @ObservedObject var viewModel: HistoryViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onChange(of: viewModel.focusRevision) {
            searchFocused = true
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard history", text: $viewModel.query)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit {
                    viewModel.selectFirstVisible()
                }
            Spacer()
            Text(countLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var content: some View {
        if viewModel.visibleItems.isEmpty {
            emptyState
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.visibleItems) { item in
                        ItemCardView(
                            item: item,
                            onSelect: { viewModel.select(item.id) },
                            onTogglePin: { viewModel.togglePin(item.id) },
                            onDelete: { viewModel.delete(item.id) }
                        )
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(viewModel.query.isEmpty ? "Copy something to get started" : "No matches")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var countLabel: String {
        let count = viewModel.visibleItems.count
        return count == 1 ? "1 item" : "\(count) items"
    }
}
