/// The application a payload was copied from. At least one identifying
/// field is guaranteed present.
public struct SourceApp: Equatable, Hashable {
    public let name: String?
    public let bundleID: String?

    public init?(name: String?, bundleID: String? = nil) {
        guard name != nil || bundleID != nil else { return nil }
        self.name = name
        self.bundleID = bundleID
    }
}
