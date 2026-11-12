import CoreGraphics
import Testing

@testable import Whisk

@Suite struct RailSegments {
    @Test func a_rail_with_every_slot_mounted_is_cards_only() {
        let segments = RailSegment.segments(count: 3) { _ in true }

        #expect(segments == [.card(0), .card(1), .card(2)])
    }

    @Test func slots_out_of_the_window_merge_into_one_gap_per_stretch() {
        let mounted = Set(10...20).union([50])

        let segments = RailSegment.segments(count: 100, isMounted: mounted.contains)

        #expect(
            segments
                == [.gap(first: 0, slots: 10)] + (10...20).map(RailSegment.card)
                + [.gap(first: 21, slots: 29), .card(50), .gap(first: 51, slots: 49)])
    }

    @Test func an_empty_rail_has_no_segment() {
        #expect(RailSegment.segments(count: 0) { _ in true }.isEmpty)
    }

    @Test func a_gap_takes_the_room_of_the_slots_it_stands_for() {
        #expect(RailSegment.gapWidth(slots: 1, slot: 210, spacing: 14) == 210)
        let three: CGFloat = 3 * 210 + 2 * 14
        #expect(RailSegment.gapWidth(slots: 3, slot: 210, spacing: 14) == three)
    }

    @Test func the_rail_is_as_long_with_gaps_as_with_every_slot_laid_out() {
        let slot: CGFloat = 210
        let spacing: CGFloat = 14
        let segments = RailSegment.segments(count: 1_464) { (40...64).contains($0) || $0 == 0 || $0 == 900 }

        let widths = segments.map { segment -> CGFloat in
            switch segment {
            case .card: slot
            case .gap(_, let slots): RailSegment.gapWidth(slots: slots, slot: slot, spacing: spacing)
            }
        }
        let length = widths.reduce(0, +) + CGFloat(segments.count - 1) * spacing

        #expect(length == 1_464 * slot + 1_463 * spacing)
    }
}
