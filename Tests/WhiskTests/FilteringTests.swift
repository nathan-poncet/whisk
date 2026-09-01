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
        #expect(Payload.text(" #7d9471 ").parsedColor != nil)
        #expect(Payload.text("#7D947").category == .text)
    }

    @Test func every_common_color_notation_is_recognized() {
        #expect(Payload.text("#abc").category == .color)
        #expect(Payload.text("#abcd").category == .color)
        #expect(Payload.text("#AABBCCDD").category == .color)
        #expect(Payload.text("rgb(255, 107, 53)").category == .color)
        #expect(Payload.text("rgb(100%, 0%, 20%)").category == .color)
        #expect(Payload.text("rgba(255 107 53 / 0.5)").category == .color)
        #expect(Payload.text("hsl(14, 100%, 60%)").category == .color)
        #expect(Payload.text("hsla(14deg 100% 60% / 40%)").category == .color)
        #expect(Payload.text("hsv(14, 79%, 100%)").category == .color)
        #expect(Payload.text("hsb(14, 79, 100)").category == .color)

        #expect(Payload.text("abc").category == .text)
        #expect(Payload.text("rgb(hello, there, friend)").category == .text)
        #expect(Payload.text("rgb(1, 2)").category == .text)
        #expect(Payload.text("I said rgb(1, 2, 3) in a sentence").category == .text)
    }

    @Test func color_notations_convert_to_the_same_srgb_components() {
        let red = ParsedColor(red: 1, green: 0, blue: 0)
        #expect(ParsedColor.parse("#ff0000") == red)
        #expect(ParsedColor.parse("#f00") == red)
        #expect(ParsedColor.parse("rgb(255, 0, 0)") == red)
        #expect(ParsedColor.parse("hsl(0, 100%, 50%)") == red)
        #expect(ParsedColor.parse("hsv(0, 100%, 100%)") == red)

        #expect(ParsedColor.parse("hsl(120, 100%, 50%)") == ParsedColor(red: 0, green: 1, blue: 0))
        #expect(ParsedColor.parse("rgba(0, 0, 255, 0.5)") == ParsedColor(red: 0, green: 0, blue: 1, alpha: 0.5))
        #expect(ParsedColor.parse("rgb(300, -20, 0)") == red)
    }
}

@Suite struct HistoryFiltering {
    let clock = FakeClock()
    let filter = FilterHistory()

    private func seededHistory() -> History {
        History()
            .recording(
                .text("let x = api.compute(1)"), from: SourceApp(name: "Ghostty", bundleID: "dev.ghostty"),
                at: clock.now()
            )
            .recording(.text("plain words"), from: SourceApp(name: "Slack", bundleID: "com.slack"), at: clock.now())
            .recording(.text("#FF6B35"), from: SourceApp(name: "Slack", bundleID: "com.slack"), at: clock.now())
    }

    @Test func items_recorded_before_bundle_ids_still_match_their_app() {
        let history = History()
            .recording(.text("old era"), from: SourceApp(name: "Slack"), at: clock.now())
            .recording(.text("new era"), from: SourceApp(name: "Slack", bundleID: "com.slack"), at: clock.now())

        let matches = filter(
            history,
            filter: HistoryFilter(sources: [SourceApp(name: "Slack", bundleID: "com.slack")].compactMap { $0 })
        )

        #expect(matches.count == 2)
    }

    @Test func filtering_by_source_keeps_only_that_apps_items() throws {
        let slack = try #require(SourceApp(name: "Slack", bundleID: "com.slack"))

        let matches = filter(seededHistory(), filter: HistoryFilter(sources: [slack]))

        #expect(matches.count == 2)
        #expect(matches.allSatisfy { $0.source == slack })
    }

    @Test func filtering_by_category_keeps_only_that_kind() {
        let matches = filter(seededHistory(), filter: HistoryFilter(categories: [.code]))

        #expect(matches.map(\.payload) == [.text("let x = api.compute(1)")])
    }

    @Test func free_words_also_match_the_source_application() {
        let matches = filter(seededHistory(), filter: HistoryFilter(query: "ghostty"))

        #expect(matches.map(\.payload) == [.text("let x = api.compute(1)")])
    }

    @Test func the_app_operator_restricts_to_one_application() {
        let matches = filter(seededHistory(), filter: HistoryFilter(query: "app:slack"))

        #expect(matches.count == 2)
        #expect(matches.allSatisfy { $0.source?.name == "Slack" })
    }

    @Test func the_type_operator_restricts_to_a_category() {
        let matches = filter(seededHistory(), filter: HistoryFilter(query: "type:code"))

        #expect(matches.map(\.payload) == [.text("let x = api.compute(1)")])
    }

    @Test func operators_and_free_words_combine_with_and_semantics() {
        let none = filter(seededHistory(), filter: HistoryFilter(query: "app:slack type:code"))
        #expect(none.isEmpty)

        let one = filter(seededHistory(), filter: HistoryFilter(query: "app:slack plain"))
        #expect(one.map(\.payload) == [.text("plain words")])
    }

    @Test func several_sources_combine_with_or_semantics() throws {
        let slack = try #require(SourceApp(name: "Slack", bundleID: "com.slack"))
        let ghostty = try #require(SourceApp(name: "Ghostty", bundleID: "dev.ghostty"))

        let matches = filter(seededHistory(), filter: HistoryFilter(sources: [slack, ghostty]))

        #expect(matches.count == 3)
    }

    @Test func several_categories_combine_with_or_semantics() {
        let matches = filter(seededHistory(), filter: HistoryFilter(categories: [.code, .color]))

        #expect(matches.count == 2)
        #expect(matches.contains { $0.payload == .text("let x = api.compute(1)") })
        #expect(matches.contains { $0.payload == .text("#FF6B35") })
    }

    @Test func the_pinned_filter_keeps_only_pinned_items() {
        let history = History()
            .recording(.text("loose"), from: nil, at: clock.now())
            .recording(.text("kept"), from: nil, at: clock.now())
        let pinnedID = history.items[0].id
        let pinned = history.togglingPin(pinnedID)

        let matches = filter(pinned, filter: HistoryFilter(pinnedOnly: true))

        #expect(matches.map(\.payload) == [.text("kept")])
    }

    @Test func retention_purges_old_unpinned_items_and_persists() throws {
        let clock = FakeClock()
        let store = InMemoryHistoryStore()
        let enforce = EnforceRetention(store: store)
        var history = History()
            .recording(.text("ancient"), from: nil, at: clock.now())
        history = history.togglingPin(history.items[0].id)
        history = history.recording(.text("old unpinned"), from: nil, at: clock.now())
        clock.advance(by: 100_000)
        history = history.recording(.text("fresh"), from: nil, at: clock.now())

        let policy = RetentionPolicy(maxAge: 86_400)
        let purged = try enforce(history, policy: policy, now: clock.now())

        #expect(purged.items.map(\.payload) == [.text("fresh"), .text("ancient")])
        #expect(store.stored == purged.items)

        let unchanged = try enforce(purged, policy: policy, now: clock.now())
        #expect(unchanged == purged)
        #expect(store.saveCount == 1)
    }

    @Test func retention_reapplies_a_smaller_capacity() throws {
        let clock = FakeClock()
        let store = InMemoryHistoryStore()
        let enforce = EnforceRetention(store: store)
        let history = History()
            .recording(.text("oldest"), from: nil, at: clock.now())
            .recording(.text("newest"), from: nil, at: clock.now())

        let capacity = try #require(HistoryCapacity(1))
        let bounded = try enforce(history, policy: RetentionPolicy(capacity: capacity), now: clock.now())

        #expect(bounded.items.map(\.payload) == [.text("newest")])
    }

    @Test func source_category_and_query_combine() throws {
        let slack = try #require(SourceApp(name: "Slack", bundleID: "com.slack"))

        let both = filter(seededHistory(), filter: HistoryFilter(sources: [slack], categories: [.color]))
        #expect(both.map(\.payload) == [.text("#FF6B35")])

        let none = filter(
            seededHistory(), filter: HistoryFilter(query: "plain", sources: [slack], categories: [.color]))
        #expect(none.isEmpty)
    }
}

@Suite struct VersionComparison {
    @Test func semantic_versions_compare_componentwise() {
        #expect(UpdateChecker.isNewer("0.6.0", than: "0.5.1"))
        #expect(UpdateChecker.isNewer("1.0.0", than: "0.9.9"))
        #expect(UpdateChecker.isNewer("0.5.10", than: "0.5.9"))
        #expect(!UpdateChecker.isNewer("0.5.0", than: "0.5.0"))
        #expect(!UpdateChecker.isNewer("0.4.9", than: "0.5.0"))
    }
}
