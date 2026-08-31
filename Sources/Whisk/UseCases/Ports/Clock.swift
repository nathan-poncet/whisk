import Foundation

/// Source of the current time, injected so use cases stay deterministic.
protocol Clock {
    func now() -> Date
}
