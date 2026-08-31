import Foundation

/// One step of keyboard navigation through the visible cards.
enum SelectionMove {
    case previous
    case next
}

/// Translates UI and OS events into use case invocations and hands each
/// result to the presenter. Owns the current history, search query and
/// keyboard selection; generic over its gateways, like the use cases it
/// drives. A storage failure is logged and the in-memory state keeps
/// working.
final class ClipboardController<Board: Pasteboard, Time: Clock, Store: HistoryStore> {
    private var history: History
    private var query = ""
    private var selectedID: UUID?

    private let capture: CaptureClipboardChange<Board, Time, Store>
    private let selectItem: SelectItem<Board, Time, Store>
    private let togglePinItem: TogglePin<Store>
    private let deleteItem: DeleteItem<Store>
    private let clearUnpinned: ClearHistory<Store>
    private let searchHistory = SearchHistory()
    private let presenter: HistoryPresenter
    private let clock: Time
    private let present: (HistoryViewState) -> Void

    init(
        pasteboard: Board,
        store: Store,
        clock: Time,
        presenter: HistoryPresenter = HistoryPresenter(),
        present: @escaping (HistoryViewState) -> Void
    ) {
        self.clock = clock
        self.presenter = presenter
        self.present = present
        capture = CaptureClipboardChange(pasteboard: pasteboard, clock: clock, store: store)
        selectItem = SelectItem(pasteboard: pasteboard, clock: clock, store: store)
        togglePinItem = TogglePin(store: store)
        deleteItem = DeleteItem(store: store)
        clearUnpinned = ClearHistory(store: store)
        do {
            history = try LoadHistory(store: store)()
        } catch {
            NSLog("Whisk: could not load history — %@", String(describing: error))
            history = History()
        }
        refresh()
    }

    func pollTick() {
        mutate { try capture(into: $0) }
    }

    func search(_ newQuery: String) {
        query = newQuery
        selectedID = nil
        refresh()
    }

    func select(_ id: UUID) {
        mutate { try selectItem(id, in: $0) }
    }

    /// Moves the keyboard selection through the visible cards, clamped at
    /// both ends.
    func moveSelection(_ step: SelectionMove) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        guard let current = selectedID,
            let index = items.firstIndex(where: { $0.id == current })
        else {
            selectedID = items.first?.id
            refresh()
            return
        }
        let destination = step == .next ? min(index + 1, items.count - 1) : max(index - 1, 0)
        selectedID = items[destination].id
        refresh()
    }

    /// Puts the highlighted card back on the pasteboard; the first visible
    /// card counts as highlighted until the selection is stepped.
    @discardableResult
    func activateSelected() -> Bool {
        guard let id = selectedID ?? visibleItems.first?.id else { return false }
        select(id)
        return true
    }

    func togglePin(_ id: UUID) {
        mutate { try togglePinItem(id, in: $0) }
    }

    func delete(_ id: UUID) {
        mutate { try deleteItem(id, in: $0) }
    }

    func clear() {
        mutate { try clearUnpinned($0) }
    }

    func panelWillShow() {
        query = ""
        selectedID = nil
        refresh()
    }

    private var visibleItems: [ClipboardItem] {
        searchHistory(history, query: query)
    }

    private func mutate(_ transform: (History) throws -> History) {
        let previous = history
        do {
            history = try transform(history)
        } catch {
            NSLog("Whisk: storage failure — %@", String(describing: error))
        }
        guard history != previous else { return }
        refresh()
    }

    private func refresh() {
        let items = visibleItems
        if selectedID == nil || !items.contains(where: { $0.id == selectedID }) {
            selectedID = items.first?.id
        }
        present(presenter.present(items: items, query: query, now: clock.now(), selectedID: selectedID))
    }
}
