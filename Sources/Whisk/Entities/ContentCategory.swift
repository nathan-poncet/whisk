import Foundation

/// What a payload is, as users think of it — the classification behind
/// category filters and card previews.
enum ContentCategory: String, CaseIterable, Equatable {
    case text
    case code
    case color
    case link
    case image
    case files
}

extension Payload {
    var category: ContentCategory {
        switch self {
        case .link: return .link
        case .image: return .image
        case .fileReferences: return .files
        case .text(let value):
            if ParsedColor.parse(value) != nil { return .color }
            if Self.readsAsCode(value) { return .code }
            return .text
        }
    }

    /// The color the payload spells out, in any recognized notation.
    var parsedColor: ParsedColor? {
        guard case .text(let value) = self else { return nil }
        return ParsedColor.parse(value)
    }

    /// Scoring heuristic, deliberately approximate: this classifies a card,
    /// it does not parse a language.
    static func readsAsCode(_ text: String) -> Bool {
        guard text.count >= 12 else { return false }
        var score = 0
        for marker in codeMarkers where text.contains(marker) {
            score += 2
        }
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasSuffix("{") || trimmed.hasSuffix("}") || trimmed.hasSuffix(";") {
                score += 2
            }
            if line.hasPrefix("    ") || line.hasPrefix("\t") {
                score += 1
            }
        }
        if let methodCall, methodCall.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
            score += 2
        }
        return score >= 4
    }

    private static let codeMarkers = [
        "func ", "def ", "fn ", "let ", "var ", "const ", "import ",
        "class ", "struct ", "enum ", "#include", "defmodule ", "impl ",
        "=>", "->", "&&", "||", "==", "!=",
    ]

    private static let methodCall = try? NSRegularExpression(pattern: "\\.[A-Za-z_]\\w*\\(")
}
