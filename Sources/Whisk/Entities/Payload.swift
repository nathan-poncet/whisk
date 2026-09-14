import Foundation

/// Content captured from the pasteboard. Image bytes are opaque to the
/// kernel; the adapter that produced them owns their encoding.
enum Payload: Equatable, Hashable {
    case text(String)
    case link(URL)
    case image(Data)
    case fileReferences([String])

    /// The text a paste-time transform can rewrite: what the card holds
    /// as text, or a link's address. Files and images have none.
    var transformableText: String? {
        switch self {
        case .text(let value): return value
        case .link(let url): return url.absoluteString
        case .image, .fileReferences: return nil
        }
    }

    /// The text a search can look at; image bytes are opaque.
    var searchableText: String? {
        switch self {
        case .text(let value):
            return value
        case .link(let url):
            return url.absoluteString
        case .fileReferences(let paths):
            return paths.joined(separator: " ")
        case .image:
            return nil
        }
    }
}
