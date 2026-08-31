import Foundation

/// Translates UI and OS events into use case invocations and hands each
/// result to the presenter. Owns the current history and search query;
/// generic over its gateways, like the use cases it drives. A storage
/// failure is logged and the in-memory state keeps working.
public final class ClipboardController<Board: Pasteboard, Time: Clock, Store: HistoryStore> {
    private var history: History
    private var query = ""

    private let capture: CaptureClipboardChange<Board, Time, Store>
    private let selectItem: SelectItem<Board, Time, Store>
    private let togglePinItem: TogglePin<Store>
    private let deleteItem: DeleteItem<Store>
    private let clearUnpinned: ClearHistory<Store>
    private let searchHistory = SearchHistory()
    private let presenter: HistoryPresenter
    private let clock: Time
    private let present: (HistoryViewState) -> Void

    public init(
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

    public func pollTick() {
        mutate { try capture(into: $0) }
    }

    public func search(_ newQuery: String) {
        query = newQuery
        refresh()
    }

    public func select(_ id: UUID) {
        mutate { try selectItem(id, in: $0) }
    }

    @discardableResult
    public func selectFirstVisible() -> Bool {
        guard let first = visibleItems.first else { return false }
        select(first.id)
        return true
    }

    public func togglePin(_ id: UUID) {
        mutate { try togglePinItem(id, in: $0) }
    }

    public func delete(_ id: UUID) {
        mutate { try deleteItem(id, in: $0) }
    }

    public func clear() {
        mutate { try clearUnpinned($0) }
    }

    public func panelWillShow() {
        query = ""
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
        present(presenter.present(items: visibleItems, query: query, now: clock.now()))
    }
}
