import Foundation

/// fzf-style fuzzy matching: the pattern's characters must appear in
/// order — a subsequence — and the score rewards what fzf rewards,
/// consecutive runs and word-boundary hits, with penalties for opening
/// and stretching gaps, so the tightest, best-anchored match ranks
/// first. Smart case: an all-lowercase pattern matches insensitively.
enum FuzzyMatch {
    private static let match = 16
    private static let bonusConsecutive = 4
    private static let bonusBoundary = 8
    private static let penaltyGapStart = 3
    private static let penaltyGapExtension = 1

    /// A match with the offsets, in characters of the candidate, of the
    /// characters the pattern landed on — what a card highlights.
    struct Match: Equatable {
        let score: Int
        let positions: [Int]
    }

    static func score(pattern: String, in candidate: String) -> Int? {
        match(pattern: pattern, in: candidate)?.score
    }

    static func match(pattern: String, in candidate: String) -> Match? {
        guard !pattern.isEmpty else { return Match(score: 0, positions: []) }
        let insensitive = !pattern.contains(where: \.isUppercase)
        switch plainMatch(pattern: pattern, in: candidate, insensitive: insensitive) {
        case .matched(let match): return match
        case .unmatched: return nil
        case .notPlain:
            guard couldMatch(pattern: pattern, in: candidate, insensitive: insensitive) else { return nil }
        }
        let folded = insensitive ? candidate.lowercased() : candidate
        let needle = Array(insensitive ? pattern.lowercased() : pattern)

        // Forward pass finds the earliest end of a full match; the
        // backward pass then shrinks toward the tightest window ending
        // there — fzf's two-pass v1 heart.
        var needleIndex = 0
        var end = -1
        for (position, character) in folded.enumerated() where character == needle[needleIndex] {
            needleIndex += 1
            if needleIndex == needle.count {
                end = position
                break
            }
        }
        guard end >= 0 else { return nil }
        // Nothing past the match is read again: only that much is laid
        // out for the random access the backward pass needs.
        let text = Array(folded.prefix(end + 1))
        needleIndex = needle.count - 1
        var start = end
        var position = end
        while position >= 0 {
            if text[position] == needle[needleIndex] {
                if needleIndex == 0 {
                    start = position
                    break
                }
                needleIndex -= 1
            }
            position -= 1
        }
        return score(window: text, needle: needle, start: start, end: end)
    }

    private enum PlainOutcome {
        case matched(Match)
        case unmatched
        case notPlain
    }

    private static let carriageReturn = UInt8(ascii: "\r")

    private static func isPlain(_ byte: UInt8) -> Bool {
        byte < 0x80 && byte != carriageReturn
    }

    private static func lowered(_ byte: UInt8) -> UInt8 {
        (UInt8(ascii: "A")...UInt8(ascii: "Z")).contains(byte) ? byte | 0x20 : byte
    }

    /// The same match, read off the bytes. Most of what is copied is
    /// ASCII, where a byte is a character — except the CR of a CRLF pair —
    /// and a search walks every text of the history at each keystroke:
    /// lowercasing a text and splitting it into characters to find that it
    /// does not match was most of that cost. Anything else is left to the
    /// character-wise path.
    private static func plainMatch(pattern: String, in candidate: String, insensitive: Bool) -> PlainOutcome {
        guard pattern.utf8.allSatisfy(isPlain) else { return .notPlain }
        let needle = pattern.utf8.map { insensitive ? lowered($0) : $0 }
        var candidate = candidate
        return candidate.withUTF8 { bytes in
            var needleIndex = 0
            var end = -1
            for (position, raw) in bytes.enumerated() {
                guard isPlain(raw) else { return .notPlain }
                if (insensitive ? lowered(raw) : raw) == needle[needleIndex] {
                    needleIndex += 1
                    if needleIndex == needle.count {
                        end = position
                        break
                    }
                }
            }
            guard end >= 0 else { return .unmatched }
            // A combining mark right after the last hit would make that
            // hit another character.
            if end + 1 < bytes.count, bytes[end + 1] >= 0x80 {
                return .notPlain
            }
            let text = bytes[...end].map { insensitive ? lowered($0) : $0 }
            needleIndex = needle.count - 1
            var start = end
            var position = end
            while position >= 0 {
                if text[position] == needle[needleIndex] {
                    if needleIndex == 0 {
                        start = position
                        break
                    }
                    needleIndex -= 1
                }
                position -= 1
            }
            let asCharacter = { (byte: UInt8) in Character(Unicode.Scalar(byte)) }
            return .matched(
                score(window: text.map(asCharacter), needle: needle.map(asCharacter), start: start, end: end))
        }
    }

    /// The three signs outside ASCII that compare equal to an ASCII
    /// character, as written or once lowercased: the Greek question mark
    /// (;), the Greek varia (`) and the Kelvin sign (K).
    private static let plainLookalikes: [[UInt8]] = [[0xCD, 0xBE], [0xE1, 0xBF, 0xAF], [0xE2, 0x84, 0xAA]]

    /// Whether the character-wise path is worth running on a text that is
    /// not plain: the pattern's ASCII characters have to be there, in
    /// order, as bytes. A text holding a lookalike is never turned away.
    private static func couldMatch(pattern: String, in candidate: String, insensitive: Bool) -> Bool {
        let needle = pattern.utf8.filter { $0 < 0x80 }.map { insensitive ? lowered($0) : $0 }
        guard !needle.isEmpty else { return true }
        var candidate = candidate
        return candidate.withUTF8 { bytes in
            var needleIndex = 0
            for (position, raw) in bytes.enumerated() {
                if raw >= 0x80 {
                    if plainLookalikes.contains(where: { bytes[position...].starts(with: $0) }) {
                        return true
                    }
                } else if (insensitive ? lowered(raw) : raw) == needle[needleIndex] {
                    needleIndex += 1
                    if needleIndex == needle.count {
                        return true
                    }
                }
            }
            return false
        }
    }

    private static func score(window text: [Character], needle: [Character], start: Int, end: Int) -> Match {
        var total = 0
        var positions: [Int] = []
        var needleIndex = 0
        var previousMatched = false
        for position in start...end where needleIndex < needle.count {
            if text[position] == needle[needleIndex] {
                total += match
                if previousMatched {
                    total += bonusConsecutive
                }
                if isWordStart(text, at: position) {
                    total += bonusBoundary
                }
                positions.append(position)
                previousMatched = true
                needleIndex += 1
            } else {
                total -= previousMatched ? penaltyGapStart : penaltyGapExtension
                previousMatched = false
            }
        }
        return Match(score: total, positions: positions)
    }

    private static func isWordStart(_ text: [Character], at position: Int) -> Bool {
        guard position > 0 else { return true }
        let previous = text[position - 1]
        if previous.isWhitespace || previous.isPunctuation || previous.isSymbol || previous == "_" {
            return true
        }
        return text[position].isUppercase && previous.isLowercase
    }
}
