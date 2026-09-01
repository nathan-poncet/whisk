import Foundation

/// How much history is kept: a capacity bound plus an optional maximum
/// age. Pinned items are exempt from both, like everywhere else.
struct RetentionPolicy: Equatable {
    let capacity: HistoryCapacity
    let maxAge: TimeInterval?

    init(capacity: HistoryCapacity = .standard, maxAge: TimeInterval? = nil) {
        self.capacity = capacity
        self.maxAge = maxAge
    }

    static let standard = RetentionPolicy()
}
