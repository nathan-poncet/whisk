import Foundation
import Testing

@testable import Whisk

@Suite struct ContentClassification {
    @Test func each_payload_shape_maps_to_its_category() throws {
        let url = try #require(URL(string: "https://example.com"))

        #expect(Payload.link(url).category == .link)
        #expect(Payload.image(Data([0x01])).category == .image)
        #expect(Payload.fileReferences(["/tmp/a.txt"]).category == .files)
    }

    @Test func text_splits_into_prose_code_and_color() {
        #expect(Payload.text("Let me know when you arrive, we can talk then.").category == .text)
        #expect(Payload.text("func greet() -> String { return \"hi\" }").category == .code)
        #expect(Payload.text(" #7d9471 ").category == .color)
        #expect(Payload.text(" #7d9471 ").hexColorCode == "#7D9471")
        #expect(Payload.text("#7D947").category == .text)
    }
}

@Suite struct HistoryFiltering {
    let clock = FakeClock()
    let filter = FilterHistory()

    private func seededHistory() -> History {
        History()
            .recording(
                .text("let x = compute(1)"), from: SourceApp(name: "Ghostty", bundleID: "dev.ghostty"), at: clock.now()
            )
            .recording(.text("plain words"), from: SourceApp(name: "Slack", bundleID: "com.slack"), at: clock.now())
            .recording(.text("#FF6B35"), from: SourceApp(name: "Slack", bundleID: "com.slack"), at: clock.now())
    }

    @Test func items_recorded_before_bundle_ids_still_match_their_app() {
        let history = History()
            .recording(.text("old era"), from: SourceApp(name: "Slack"), at: clock.now())
            .recording(.text("new era"), from: SourceApp(name: "Slack", bundleID: "com.slack"), at: clock.now())

        let matches = filter(history, filter: HistoryFilter(source: SourceApp(name: "Slack", bundleID: "com.slack")))

        #expect(matches.count == 2)
    }

    @Test func filtering_by_source_keeps_only_that_apps_items() {
        let slack = SourceApp(name: "Slack", bundleID: "com.slack")

        let matches = filter(seededHistory(), filter: HistoryFilter(source: slack))

        #expect(matches.count == 2)
        #expect(matches.allSatisfy { $0.source == slack })
    }

    @Test func filtering_by_category_keeps_only_that_kind() {
        let matches = filter(seededHistory(), filter: HistoryFilter(category: .code))

        #expect(matches.map(\.payload) == [.text("let x = compute(1)")])
    }

    @Test func source_category_and_query_combine() {
        let slack = SourceApp(name: "Slack", bundleID: "com.slack")

        let both = filter(seededHistory(), filter: HistoryFilter(source: slack, category: .color))
        #expect(both.map(\.payload) == [.text("#FF6B35")])

        let none = filter(seededHistory(), filter: HistoryFilter(query: "plain", source: slack, category: .color))
        #expect(none.isEmpty)
    }
}
