import Foundation

/// Coalesces bursts of calls into the last one, main-queue only. A newer
/// call cancels the pending one; `flush` runs the pending action right
/// now — actions that consume the result call it first, so they never act
/// on a stale state.
final class Debouncer {
    private let delay: TimeInterval
    private var pending: DispatchWorkItem?
    private var pendingAction: (() -> Void)?

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func schedule(_ action: @escaping () -> Void) {
        pending?.cancel()
        pendingAction = action
        let work = DispatchWorkItem { [weak self] in
            self?.pendingAction = nil
            self?.pending = nil
            action()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func flush() {
        pending?.cancel()
        pending = nil
        if let action = pendingAction {
            pendingAction = nil
            action()
        }
    }

    func cancel() {
        pending?.cancel()
        pending = nil
        pendingAction = nil
    }
}
