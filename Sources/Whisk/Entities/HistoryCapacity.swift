/// Upper bound on the number of unpinned items a history keeps.
struct HistoryCapacity: Equatable, Hashable {
    let value: Int

    /// Rejects capacities below one.
    init?(_ raw: Int) {
        guard raw >= 1 else { return nil }
        value = raw
    }

    /// Default bound used by the application.
    static var standard: HistoryCapacity { HistoryCapacity(unchecked: 500) }

    private init(unchecked: Int) {
        value = unchecked
    }
}
