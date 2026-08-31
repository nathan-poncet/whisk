import Foundation
import Testing
@testable import Whisk

@Suite struct HistoryBehaviour {
    let clock = FakeClock()

    @Test func a_new_copy_lands_at_the_front() {
        let history = History()
            .recording(.text("first"), from: nil, at: clock.now())
            .recording(.text("second"), from: nil, at: clock.now())

        #expect(history.items.map(\.payload) == [.text("second"), .text("first")])
    }

    @Test func a_duplicate_copy_moves_the_existing_item_to_the_front_keeping_its_identity() {
        let clock = FakeClock()
        var history = History()
            .recording(.text("keep me"), from: nil, at: clock.now())
        let original = history.items[0]
        history = history.togglingPin(original.id)
        clock.advance(by: 60)
        history = history.recording(.text("other"), from: nil, at: clock.now())
        clock.advance(by: 60)

        history = history.recording(.text("keep me"), from: nil, at: clock.now())

        let front = history.items[0]
        #expect(history.items.count == 2)
        #expect(front.id == original.id)
        #expect(front.isPinned)
        #expect(front.copiedAt == clock.now())
    }

    @Test func the_oldest_unpinned_item_is_evicted_beyond_capacity() throws {
        let capacity = try #require(HistoryCapacity(2))
        let history = History(capacity: capacity)
            .recording(.text("oldest"), from: nil, at: clock.now())
            .recording(.text("middle"), from: nil, at: clock.now())
            .recording(.text("newest"), from: nil, at: clock.now())

        #expect(history.items.map(\.payload) == [.text("newest"), .text("middle")])
    }

    @Test func pinned_items_do_not_count_toward_capacity() throws {
        let capacity = try #require(HistoryCapacity(2))
        var history = History(capacity: capacity)
            .recording(.text("pinned"), from: nil, at: clock.now())
        history = history.togglingPin(history.items[0].id)

        history = history
            .recording(.text("a"), from: nil, at: clock.now())
            .recording(.text("b"), from: nil, at: clock.now())

        #expect(history.items.count == 3)
        #expect(history.items.contains { $0.payload == .text("pinned") })
    }

    @Test func clearing_removes_only_unpinned_items() {
        var history = History()
            .recording(.text("pinned"), from: nil, at: clock.now())
        history = history.togglingPin(history.items[0].id)
        history = history.recording(.text("ephemeral"), from: nil, at: clock.now())

        let cleared = history.clearingUnpinned()

        #expect(cleared.items.map(\.payload) == [.text("pinned")])
    }

    @Test func deleting_removes_the_item_regardless_of_pin() {
        var history = History()
            .recording(.text("pinned"), from: nil, at: clock.now())
        history = history.togglingPin(history.items[0].id)

        let emptied = history.deleting(history.items[0].id)

        #expect(emptied.items.isEmpty)
    }

    @Test func a_capacity_below_one_is_rejected() {
        #expect(HistoryCapacity(0) == nil)
        #expect(HistoryCapacity(-3) == nil)
        #expect(HistoryCapacity(1) != nil)
    }

    @Test func search_matches_text_links_and_file_names_case_insensitively() throws {
        let url = try #require(URL(string: "https://Example.com/Docs"))
        let history = History()
            .recording(.text("Hello World"), from: nil, at: clock.now())
            .recording(.link(url), from: nil, at: clock.now())
            .recording(.fileReferences(["/tmp/Report.pdf"]), from: nil, at: clock.now())
            .recording(.image(Data([0x89])), from: nil, at: clock.now())
        let search = SearchHistory()

        #expect(search(history, query: "hello").map(\.payload) == [.text("Hello World")])
        #expect(search(history, query: "example").map(\.payload) == [.link(url)])
        #expect(search(history, query: "report").map(\.payload) == [.fileReferences(["/tmp/Report.pdf"])])
        #expect(search(history, query: "zzz").isEmpty)
    }

    @Test func an_empty_query_returns_everything() {
        let history = History()
            .recording(.text("a"), from: nil, at: clock.now())
            .recording(.text("b"), from: nil, at: clock.now())
        let search = SearchHistory()

        #expect(search(history, query: "  ").count == 2)
    }
}
