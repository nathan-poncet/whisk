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
}
