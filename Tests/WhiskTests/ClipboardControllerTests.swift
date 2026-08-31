import Foundation
import Testing
@testable import Whisk

@Suite struct ClipboardControllerBehaviour {
    final class StateSpy {
        private(set) var states: [HistoryViewState] = []
        var last: HistoryViewState { states.last ?? .empty }
        func record(_ state: HistoryViewState) { states.append(state) }
    }

    @Test func a_poll_tick_with_a_change_presents_the_new_card_first() {
        let pasteboard = ScriptedPasteboard()
        pasteboard.pendingSnapshots = [PasteboardSnapshot(payload: .text("fresh"), source: SourceApp(name: "Safari"))]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: pasteboard, store: InMemoryHistoryStore(), clock: FakeClock(), present: spy.record
        )

        controller.pollTick()

        #expect(spy.last.cards.first?.preview == .text("fresh"))
        #expect(spy.last.cards.first?.sourceLabel == "Safari")
        #expect(spy.last.countLabel == "1 item")
    }

    @Test func a_poll_tick_without_a_change_presents_nothing_new() {
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: InMemoryHistoryStore(), clock: FakeClock(), present: spy.record
        )
        let presentedAfterInit = spy.states.count

        controller.pollTick()

        #expect(spy.states.count == presentedAfterInit)
    }

    @Test func searching_presents_only_matching_cards() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("hello world")), anItem(.text("something else"))]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )
        #expect(spy.last.cards.count == 2)

        controller.search("hello")

        #expect(spy.last.cards.map(\.preview) == [.text("hello world")])
        #expect(spy.last.query == "hello")
    }

    @Test func selecting_writes_the_payload_back_and_presents_it_first() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("newer")), anItem(.text("wanted"))]
        let pasteboard = ScriptedPasteboard()
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: pasteboard, store: store, clock: FakeClock(), present: spy.record
        )
        let wantedID = spy.last.cards[1].id

        controller.select(wantedID)

        #expect(pasteboard.written == [.text("wanted")])
        #expect(spy.last.cards.first?.id == wantedID)
    }

    @Test func activating_the_selection_reports_whether_anything_was_there() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("only"))]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )

        controller.search("no match")
        #expect(controller.activateSelected() == false)

        controller.search("")
        #expect(controller.activateSelected() == true)
    }

    @Test func the_first_visible_card_is_selected_by_default() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("front")), anItem(.text("back"))]
        let spy = StateSpy()
        _ = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )

        #expect(spy.last.selectedID == spy.last.cards.first?.id)
        #expect(spy.last.cards.map(\.isSelected) == [true, false])
    }

    @Test func stepping_the_selection_clamps_at_both_edges() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("a")), anItem(.text("b"))]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )

        controller.moveSelection(.previous)
        #expect(spy.last.cards.map(\.isSelected) == [true, false])

        controller.moveSelection(.next)
        #expect(spy.last.cards.map(\.isSelected) == [false, true])

        controller.moveSelection(.next)
        #expect(spy.last.cards.map(\.isSelected) == [false, true])
    }

    @Test func searching_resets_the_selection_to_the_first_match() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("alpha")), anItem(.text("beta")), anItem(.text("gamma"))]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )
        controller.moveSelection(.next)

        controller.search("gamma")

        #expect(spy.last.cards.map(\.isSelected) == [true])
    }

    @Test func activation_targets_the_stepped_selection_not_the_first_card() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("front")), anItem(.text("stepped to"))]
        let pasteboard = ScriptedPasteboard()
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: pasteboard, store: store, clock: FakeClock(), present: spy.record
        )

        controller.moveSelection(.next)
        controller.activateSelected()

        #expect(pasteboard.written == [.text("stepped to")])
        #expect(spy.last.cards.first?.preview == .text("stepped to"))
    }

    @Test func a_storage_failure_keeps_the_presented_state_alive() {
        let pasteboard = ScriptedPasteboard()
        pasteboard.pendingSnapshots = [PasteboardSnapshot(payload: .text("doomed"), source: nil)]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: pasteboard, store: FailingHistoryStore(), clock: FakeClock(), present: spy.record
        )

        controller.pollTick()
        controller.search("")

        #expect(spy.last.cards.isEmpty)
    }

    @Test func highlighting_moves_the_selection_without_writing_back() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("first")), anItem(.text("second"))]
        let pasteboard = ScriptedPasteboard()
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: pasteboard, store: store, clock: FakeClock(), present: spy.record
        )
        let secondID = spy.last.cards[1].id

        controller.highlight(secondID)

        #expect(spy.last.cards.map(\.isSelected) == [false, true])
        #expect(pasteboard.written.isEmpty)

        let presented = spy.states.count
        controller.highlight(secondID)
        #expect(spy.states.count == presented)
    }

    @Test func the_rail_is_bounded_and_reports_what_it_hides() {
        let store = InMemoryHistoryStore()
        store.stored = (1...70).map { anItem(.text("item \($0)")) }
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )

        #expect(spy.last.cards.count == 60)
        #expect(spy.last.hiddenCount == 10)
        #expect(spy.last.countLabel == "70 items")

        controller.search("item 7")
        #expect(spy.last.hiddenCount == 0)
    }

    @Test func arrows_move_the_focus_between_cards_kinds_and_apps() {
        let store = InMemoryHistoryStore()
        store.stored = [
            anItem(.text("func run() { start() }"), from: "Ghostty", bundle: "dev.ghostty"),
            anItem(.text("plain words"), from: "Slack", bundle: "com.slack"),
        ]
        let pasteboard = ScriptedPasteboard()
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: pasteboard, store: store, clock: FakeClock(), present: spy.record
        )
        #expect(spy.last.filters.focusedChipID == nil)

        controller.navigate(.up)
        #expect(spy.last.filters.kinds.map(\.isFocused) == [true, false])

        controller.navigate(.right)
        #expect(spy.last.filters.kinds.map(\.isFocused) == [false, true])
        #expect(controller.activateFocused() == false)
        #expect(spy.last.cards.map(\.kindLabel) == ["code"])

        controller.navigate(.up)
        #expect(spy.last.filters.apps.map(\.isFocused) == [true, false])

        controller.navigate(.down)
        controller.navigate(.down)
        #expect(spy.last.filters.focusedChipID == nil)
        #expect(controller.activateFocused() == true)
        #expect(pasteboard.written == [.text("func run() { start() }")])
    }

    @Test func chip_toggles_filter_the_rail_and_toggle_back_off() {
        let store = InMemoryHistoryStore()
        store.stored = [
            anItem(.text("func run() { start() }"), from: "Ghostty", bundle: "dev.ghostty"),
            anItem(.text("plain words"), from: "Slack", bundle: "com.slack"),
        ]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )
        #expect(spy.last.filters.apps.map(\.label) == ["Ghostty", "Slack"])
        #expect(spy.last.filters.kinds.map(\.id) == ["text", "code"])

        controller.toggleSourceFilter("com.slack")
        #expect(spy.last.cards.map(\.sourceLabel) == ["Slack"])
        #expect(spy.last.filters.apps.map(\.isActive) == [false, true])

        controller.toggleCategoryFilter("code")
        #expect(spy.last.cards.isEmpty)

        controller.toggleSourceFilter("com.slack")
        controller.toggleCategoryFilter("code")
        #expect(spy.last.cards.count == 2)
        #expect(spy.last.filters.hasActiveChip == false)
    }

    @Test func the_panel_reset_clears_the_query() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("alpha")), anItem(.text("beta"))]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )
        controller.search("alpha")

        controller.panelWillShow()

        #expect(spy.last.query.isEmpty)
        #expect(spy.last.cards.count == 2)
    }
}
