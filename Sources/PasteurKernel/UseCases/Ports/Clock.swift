import Foundation

/// Source of the current time, injected so use cases stay deterministic.
public protocol Clock {
    func now() -> Date
}
