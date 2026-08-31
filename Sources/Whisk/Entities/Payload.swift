import Foundation

/// Content captured from the pasteboard. Image bytes are opaque to the
/// kernel; the adapter that produced them owns their encoding.
enum Payload: Equatable, Hashable {
    case text(String)
    case link(URL)
    case image(Data)
    case fileReferences([String])

    func matches(_ query: String) -> Bool {
        switch self {
        case .text(let value):
            return value.localizedCaseInsensitiveContains(query)
        case .link(let url):
            return url.absoluteString.localizedCaseInsensitiveContains(query)
        case .fileReferences(let paths):
            return paths.contains { $0.localizedCaseInsensitiveContains(query) }
        case .image:
            return false
        }
    }
}
