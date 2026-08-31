/// The application a payload was copied from. At least one identifying
/// field is guaranteed present.
struct SourceApp: Equatable, Hashable {
    let name: String?
    let bundleID: String?

    init?(name: String?, bundleID: String? = nil) {
        guard name != nil || bundleID != nil else { return nil }
        self.name = name
        self.bundleID = bundleID
    }

    /// Stable identity for filtering; the invariant guarantees one field.
    var filterKey: String {
        bundleID ?? name ?? ""
    }

    /// Lenient identity: items recorded before the bundle id existed carry
    /// a name only, and must still count as the same application.
    func matches(_ other: SourceApp) -> Bool {
        if let mine = bundleID, let theirs = other.bundleID {
            return mine == theirs
        }
        return name != nil && name == other.name
    }
}
