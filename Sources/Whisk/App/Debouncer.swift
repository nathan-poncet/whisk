import Foundation

/// Coalesces bursts of calls into the last one, main-queue only. A newer
/// call cancels the pending one; `flush` runs the pending action right
/// now — actions that consume the result call it first, so they never act
/// on a stale state.
final class Debouncer {
    /// Hands a work item to the clock that will run it after the delay;
    /// the main queue in production, a hand-cranked one in tests.
    typealias Scheduler = (TimeInterval, DispatchWorkItem) -> Void

    private let delay: TimeInterval
    private let scheduler: Scheduler
    private var pending: DispatchWorkItem?
    private var pendingAction: (() -> Void)?

    init(
        delay: TimeInterval,
        scheduler: @escaping Scheduler = { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    ) {
        self.delay = delay
        self.scheduler = scheduler
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
        scheduler(delay, work)
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
