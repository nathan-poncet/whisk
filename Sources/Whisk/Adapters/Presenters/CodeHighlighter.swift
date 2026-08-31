import Foundation

/// A colored span inside a code preview, in UTF-16 offsets so views can
/// apply attributes without re-parsing.
struct CodeToken: Equatable {
    enum Kind: Equatable {
        case keyword
        case string
        case comment
        case number
    }

    let kind: Kind
    let start: Int
    let length: Int
}

/// Pure, language-agnostic code detection and tokenization: a scoring
/// heuristic decides whether text reads as code, and regex passes extract
/// comments, strings, keywords and numbers. Deliberately approximate — this
/// feeds a card preview, not an editor.
enum CodeHighlighter {
    /// Tokens when the text looks like code, nil when it reads as prose.
    static func highlight(_ text: String) -> [CodeToken]? {
        guard looksLikeCode(text) else { return nil }
        return tokens(in: text)
    }

    private static let markers = [
        "func ", "def ", "fn ", "let ", "var ", "const ", "import ",
        "class ", "struct ", "enum ", "#include", "defmodule ", "impl ",
        "=>", "->", "&&", "||", "==", "!=",
    ]

    static func looksLikeCode(_ text: String) -> Bool {
        guard text.count >= 12 else { return false }
        var score = 0
        for marker in markers where text.contains(marker) {
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
        if matches(methodCall, in: text) {
            score += 2
        }
        return score >= 4
    }

    static func tokens(in text: String) -> [CodeToken] {
        // Previews show a handful of lines; tokenizing megabytes of a
        // copied file would be wasted work.
        let scanned = String(text.prefix(4000))
        let range = NSRange(scanned.startIndex..., in: scanned)
        var claimed: [NSRange] = []
        var result: [CodeToken] = []
        for (kind, pattern) in passes {
            guard let pattern else { continue }
            pattern.enumerateMatches(in: scanned, range: range) { match, _, _ in
                guard let found = match?.range, found.length > 0 else { return }
                guard !claimed.contains(where: { NSIntersectionRange($0, found).length > 0 }) else { return }
                claimed.append(found)
                result.append(CodeToken(kind: kind, start: found.location, length: found.length))
            }
        }
        return result.sorted { $0.start < $1.start }
    }

    // Comments and strings run first so keywords inside them stay claimed.
    private static let passes: [(CodeToken.Kind, NSRegularExpression?)] = [
        (.comment, regex("//[^\\n]*|/\\*[\\s\\S]*?\\*/|(?<=^|\\s)#(?!include)[^\\n]*")),
        (.string, regex("\"(?:\\\\.|[^\"\\\\\\n])*\"|'(?:\\\\.|[^'\\\\\\n])*'")),
        (
            .keyword,
            regex(
                "\\b(?:func|def|fn|let|var|const|import|from|return|if|else|elif|for|while|switch"
                    + "|case|class|struct|enum|protocol|extension|public|private|internal|final|static"
                    + "|guard|defer|async|await|try|catch|throw|throws|impl|pub|mut|match|do|end"
                    + "|defmodule|defp|nil|null|true|false|self|this|new|void|int|string|bool)\\b"
            )
        ),
        (.number, regex("\\b\\d+(?:\\.\\d+)?\\b")),
    ]

    private static let methodCall = regex("\\.[A-Za-z_]\\w*\\(")

    private static func matches(_ pattern: NSRegularExpression?, in text: String) -> Bool {
        guard let pattern else { return false }
        let range = NSRange(text.startIndex..., in: text)
        return pattern.firstMatch(in: text, range: range) != nil
    }

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern)
    }
}
