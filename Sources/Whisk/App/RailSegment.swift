import CoreGraphics

/// What the rail hands the layout engine: the cards it displays, and one
/// gap for each stretch of slots it does not. A slot per card, displayed
/// or not, made every selection move and every keystroke of a search
/// diff and lay out the whole history; a gap holds the same room as the
/// slots it stands for, so the scroll extent and every card's place are
/// what they would be with all of them laid out.
enum RailSegment: Hashable {
    case card(Int)
    case gap(first: Int, slots: Int)

    static func segments(count: Int, isMounted: (Int) -> Bool) -> [RailSegment] {
        var segments: [RailSegment] = []
        var gapStart: Int?
        for index in 0..<count {
            if isMounted(index) {
                if let start = gapStart {
                    segments.append(.gap(first: start, slots: index - start))
                    gapStart = nil
                }
                segments.append(.card(index))
            } else if gapStart == nil {
                gapStart = index
            }
        }
        if let start = gapStart {
            segments.append(.gap(first: start, slots: count - start))
        }
        return segments
    }

    /// The slots themselves and the spacing between them; the spacing on
    /// either side of the gap is the stack's own.
    static func gapWidth(slots: Int, slot: CGFloat, spacing: CGFloat) -> CGFloat {
        CGFloat(slots) * slot + CGFloat(max(0, slots - 1)) * spacing
    }
}
