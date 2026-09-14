import AppKit
import SwiftUI

/// Renders a code preview by applying the presenter's tokens as colors on
/// a monospaced base.
struct CodeTextView: View {
    let text: String
    let tokens: [CodeToken]
    var lineLimit: Int? = 8

    var body: some View {
        Text(Self.attributed(text, tokens: tokens))
            .font(.system(size: 12, design: .monospaced))
            .lineSpacing(1.5)
            .lineLimit(lineLimit)
    }

    /// The text in the label color, each token recolored by kind; a token
    /// pointing past the end is ignored rather than trusted.
    static func attributed(_ text: String, tokens: [CodeToken]) -> AttributedString {
        let rendered = NSMutableAttributedString(string: text)
        let full = NSRange(location: 0, length: rendered.length)
        rendered.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)
        for token in tokens {
            let range = NSRange(location: token.start, length: token.length)
            guard range.location + range.length <= rendered.length else { continue }
            rendered.addAttribute(.foregroundColor, value: color(for: token.kind), range: range)
        }
        return AttributedString(rendered)
    }

    static func color(for kind: CodeToken.Kind) -> NSColor {
        switch kind {
        case .keyword: return .systemPurple
        case .string: return .systemRed
        case .comment: return .secondaryLabelColor
        case .number: return .systemBlue
        }
    }
}
