import Combine
import Foundation
import PasteurKernel

/// Presentation state for the history panel; every mutation goes through a
/// kernel use case. A storage failure keeps the in-memory history alive.
final class HistoryViewModel: ObservableObject {
    @Published private(set) var history: History
    @Published var query = ""
    @Published private(set) var focusRevision = 0

    var onSelection: (() -> Void)?

    private let useCases: UseCaseBundle
    private let search = SearchHistory()
    private var pollTimer: Timer?

    init(useCases: UseCaseBundle) {
        self.useCases = useCases
        do {
            history = try useCases.load()
        } catch {
            NSLog("Pasteur: could not load history — %@", String(describing: error))
            history = History()
        }
    }

    var visibleItems: [ClipboardItem] {
        search(history, query: query)
    }

    func startPolling(interval: TimeInterval = 0.25) {
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.captureChange()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    func panelWillShow() {
        query = ""
        focusRevision += 1
    }

    func select(_ id: UUID) {
        apply { try useCases.select(id, $0) }
        onSelection?()
    }

    func selectFirstVisible() {
        guard let first = visibleItems.first else { return }
        select(first.id)
    }

    func togglePin(_ id: UUID) {
        apply { try useCases.togglePin(id, $0) }
    }

    func delete(_ id: UUID) {
        apply { try useCases.delete(id, $0) }
    }

    func clear() {
        apply(useCases.clear)
    }

    private func captureChange() {
        apply(useCases.capture)
    }

    private func apply(_ transform: (History) throws -> History) {
        do {
            history = try transform(history)
        } catch {
            NSLog("Pasteur: storage failure — %@", String(describing: error))
        }
    }
}
