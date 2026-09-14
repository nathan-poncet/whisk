import Foundation
import Testing

@testable import Whisk

@Suite struct PanelActionWiring {
    private final class Fixture {
        let pasteboard = ScriptedPasteboard()
        let store = InMemoryHistoryStore()
        let clock = HandCrankedScheduler()
        let spy = ClipboardControllerBehaviour.StateSpy()
        private(set) var hides = 0
        private(set) var pastes = 0
        private(set) var drags = 0
        let controller: ClipboardController<ScriptedPasteboard, FakeClock, InMemoryHistoryStore, RecordingLogger>
        private(set) var actions: PanelActions?

        init(_ items: [ClipboardItem]) {
            store.stored = items
            controller = ClipboardController(
                pasteboard: pasteboard, store: store, clock: FakeClock(), present: spy.record)
            actions = PanelWiring.actions(
                for: controller,
                searchDebounce: Debouncer(delay: 0.18, scheduler: clock.schedule),
                hidePanel: { [unowned self] in hides += 1 },
                paste: { [unowned self] in pastes += 1 },
                dragBegan: { [unowned self] in drags += 1 })
        }

        convenience init(_ payloads: [Payload]) {
            self.init(payloads.map { anItem($0) })
        }

        var wired: PanelActions {
            get throws { try #require(actions) }
        }
    }

    @Test func search_keystrokes_coalesce_into_the_last_query() throws {
        let fixture = Fixture([.text("alpha"), .text("beta")])

        try fixture.wired.search("a")
        try fixture.wired.search("al")
        #expect(fixture.spy.last.query == "")

        fixture.clock.fire()

        #expect(fixture.spy.last.query == "al")
        #expect(fixture.spy.last.cards.map(\.preview) == [.text("alpha")])
    }

    @Test func consuming_actions_flush_the_pending_query_then_close_and_paste() throws {
        let fixture = Fixture([.text("alpha"), .text("beta")])

        try fixture.wired.search("bet")
        try fixture.wired.activate()

        #expect(fixture.pasteboard.written == [.text("beta")])
        #expect(fixture.hides == 1)
        #expect(fixture.pastes == 1)
    }

    @Test func selecting_a_card_writes_it_closes_and_pastes_and_the_cursor_stays_put() throws {
        let fixture = Fixture([.text("alpha"), .text("beta")])
        let beta = fixture.spy.last.cards[1].id

        try fixture.wired.select(beta)
        try fixture.wired.activatePlain()

        #expect(fixture.pasteboard.written == [.text("beta"), .text("alpha")])
        #expect(fixture.hides == 2)
        #expect(fixture.pastes == 2)
    }

    @Test func an_empty_rail_position_neither_closes_nor_pastes() throws {
        let fixture = Fixture([.text("alpha")])

        try fixture.wired.activateCard(5)
        try fixture.wired.search("zzz")
        fixture.clock.fire()
        try fixture.wired.activate()

        #expect(fixture.hides == 0)
        #expect(fixture.pastes == 0)
        #expect(fixture.pasteboard.written.isEmpty)
    }

    @Test func opening_the_panel_cancels_a_pending_search() throws {
        let fixture = Fixture([.text("alpha"), .text("beta")])

        try fixture.wired.search("bet")
        try fixture.wired.panelWillShow()
        fixture.clock.fire()

        #expect(fixture.spy.last.query == "")
        #expect(fixture.spy.last.cards.count == 2)
    }

    @Test func navigation_and_edits_flush_the_query_while_filters_and_drags_pass_straight_through() throws {
        let fixture = Fixture([.text("alpha"), .text("beta"), .text("gamma")])

        try fixture.wired.search("a")
        try fixture.wired.navigate(.right)
        #expect(fixture.spy.last.query == "a")
        #expect(fixture.spy.last.cards.map(\.isSelected) == [false, true, false])

        try fixture.wired.jumpToEdge(.start)
        try fixture.wired.stackSelected()
        #expect(fixture.spy.last.stackCount == 1)

        try fixture.wired.togglePinSelected()
        try fixture.wired.deleteSelected()
        #expect(fixture.spy.last.cards.map(\.preview) == [.text("beta"), .text("gamma")])

        try fixture.wired.toggleCategoryFilter("text")
        try fixture.wired.focusCategoryChip("text")
        try fixture.wired.switchChipGroup()
        let gamma = fixture.spy.last.cards[1].id
        try fixture.wired.highlight(gamma)
        try fixture.wired.togglePin(gamma)
        try fixture.wired.delete(gamma)
        try fixture.wired.dragBegan()

        #expect(fixture.spy.last.cards.map(\.preview) == [.text("beta")])
        #expect(fixture.drags == 1)
        #expect(fixture.hides == 0)
    }

    @Test func source_chips_route_to_the_controller() throws {
        let fixture = Fixture([
            anItem(.text("plain"), from: "Slack", bundle: "com.slack"),
            anItem(.text("release notes"), from: "Notes", bundle: "com.apple.notes"),
        ])

        try fixture.wired.focusSourceChip("com.slack")
        #expect(fixture.spy.last.filters.focusedChipID == "com.slack")

        try fixture.wired.toggleSourceFilter("com.slack")
        #expect(fixture.spy.last.cards.map(\.sourceLabel) == ["Slack"])
    }
}
