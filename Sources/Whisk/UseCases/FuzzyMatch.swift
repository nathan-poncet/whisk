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

    static func score(pattern: String, in candidate: String) -> Int? {
        guard !pattern.isEmpty else { return 0 }
        let insensitive = !pattern.contains(where: \.isUppercase)
        let text = Array(insensitive ? candidate.lowercased() : candidate)
        let needle = Array(insensitive ? pattern.lowercased() : pattern)
        guard needle.count <= text.count else { return nil }

        // Forward pass finds the earliest end of a full match; the
        // backward pass then shrinks toward the tightest window ending
        // there — fzf's two-pass v1 heart.
        var needleIndex = 0
        var end = -1
        for (position, character) in text.enumerated() where character == needle[needleIndex] {
            needleIndex += 1
            if needleIndex == needle.count {
                end = position
                break
            }
        }
        guard end >= 0 else { return nil }
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

    private static func score(window text: [Character], needle: [Character], start: Int, end: Int) -> Int {
        var total = 0
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
                previousMatched = true
                needleIndex += 1
            } else {
                total -= previousMatched ? penaltyGapStart : penaltyGapExtension
                previousMatched = false
            }
        }
        return total
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
