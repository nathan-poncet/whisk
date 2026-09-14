import Foundation

/// One way of rewriting a textual card as it is pasted. Pure: the card
/// itself never changes. nil when the text is not something the transform
/// can read — broken base64, no JSON — so the caller pastes nothing rather
/// than garbage.
enum TextTransform: String, CaseIterable {
    case uppercase
    case lowercase
    case trimmed
    case singleLine
    case withoutAccents
    case urlEncoded
    case urlDecoded
    case base64Encoded
    case base64Decoded
    case prettyJSON

    func apply(to text: String) -> String? {
        switch self {
        case .uppercase:
            return text.uppercased()
        case .lowercase:
            return text.lowercased()
        case .trimmed:
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .singleLine:
            let lines = text.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return lines.joined(separator: " ")
        case .withoutAccents:
            return text.applyingTransform(.stripDiacritics, reverse: false)
        case .urlEncoded:
            return text.addingPercentEncoding(withAllowedCharacters: Self.unreserved)
        case .urlDecoded:
            return text.removingPercentEncoding
        case .base64Encoded:
            return Data(text.utf8).base64EncodedString()
        case .base64Decoded:
            guard let data = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        case .prettyJSON:
            guard let data = text.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data),
                let pretty = try? JSONSerialization.data(
                    withJSONObject: object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            else { return nil }
            return String(decoding: pretty, as: UTF8.self)
        }
    }

    /// RFC 3986 unreserved characters: everything else is percent-encoded,
    /// spaces included.
    private static let unreserved = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
}
