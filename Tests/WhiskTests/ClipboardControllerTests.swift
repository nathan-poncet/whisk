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

    @Test func the_chip_row_is_one_line_and_arrows_cross_the_separator() {
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
        #expect(spy.last.filters.apps.map(\.isFocused) == [true, false])

        controller.navigate(.right)
        controller.navigate(.right)
        #expect(spy.last.filters.kinds.map(\.isFocused) == [true, false])

        controller.navigate(.left)
        #expect(spy.last.filters.apps.map(\.isFocused) == [false, true])

        controller.navigate(.down)
        #expect(spy.last.filters.focusedChipID == nil)
        #expect(controller.activateFocused() == true)
        #expect(pasteboard.written == [.text("func run() { start() }")])
    }

    @Test func the_group_switch_shortcut_jumps_across_the_separator() {
        let store = InMemoryHistoryStore()
        store.stored = [
            anItem(.text("func run() { start() }"), from: "Ghostty", bundle: "dev.ghostty"),
            anItem(.text("plain words"), from: "Slack", bundle: "com.slack"),
        ]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )

        controller.switchChipGroup()
        #expect(spy.last.filters.apps.map(\.isFocused) == [true, false])

        controller.switchChipGroup()
        #expect(spy.last.filters.kinds.first?.isFocused == true)

        controller.switchChipGroup()
        #expect(spy.last.filters.apps.map(\.isFocused) == [true, false])
    }

    @Test func hovering_a_chip_moves_the_shared_keyboard_focus() {
        let store = InMemoryHistoryStore()
        store.stored = [
            anItem(.text("func run() { start() }"), from: "Ghostty", bundle: "dev.ghostty"),
            anItem(.text("plain words"), from: "Slack", bundle: "com.slack"),
        ]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )

        controller.focusSourceChip("com.slack")
        #expect(spy.last.filters.apps.map(\.isFocused) == [false, true])

        controller.navigate(.left)
        #expect(spy.last.filters.apps.map(\.isFocused) == [true, false])

        controller.focusCategoryChip("code")
        #expect(spy.last.filters.kinds.map(\.isFocused) == [false, true])
        #expect(spy.last.filters.apps.allSatisfy { !$0.isFocused })
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

    @Test func pausing_consumes_changes_without_recording_them() {
        let pasteboard = ScriptedPasteboard()
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: pasteboard, store: InMemoryHistoryStore(), clock: FakeClock(), present: spy.record
        )

        controller.setPaused(true)
        pasteboard.pendingSnapshots = [PasteboardSnapshot(payload: .text("secret"), source: nil)]
        controller.pollTick()
        #expect(spy.last.cards.isEmpty)

        controller.setPaused(false)
        controller.pollTick()
        #expect(spy.last.cards.isEmpty)

        pasteboard.pendingSnapshots = [PasteboardSnapshot(payload: .text("visible"), source: nil)]
        controller.pollTick()
        #expect(spy.last.cards.map(\.preview) == [.text("visible")])
    }

    @Test func copies_from_excluded_apps_are_never_recorded() {
        let pasteboard = ScriptedPasteboard()
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: pasteboard, store: InMemoryHistoryStore(), clock: FakeClock(), present: spy.record
        )
        controller.applyExclusions(["com.apple.keychainaccess"])

        pasteboard.pendingSnapshots = [
            PasteboardSnapshot(
                payload: .text("hunter2"),
                source: SourceApp(name: "Keychain Access", bundleID: "com.apple.keychainaccess")
            ),
            PasteboardSnapshot(payload: .text("plain"), source: SourceApp(name: "Notes", bundleID: "com.apple.Notes")),
        ]
        controller.pollTick()
        controller.pollTick()

        #expect(spy.last.cards.map(\.preview) == [.text("plain")])
    }

    @Test func command_digits_paste_by_rail_position() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("first")), anItem(.text("second"))]
        let pasteboard = ScriptedPasteboard()
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: pasteboard, store: store, clock: FakeClock(), present: spy.record
        )

        #expect(controller.activate(at: 1) == true)
        #expect(pasteboard.written == [.text("second")])
        #expect(controller.activate(at: 9) == false)
    }

    @Test func the_pinned_chip_appears_with_a_pin_and_filters_the_rail() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("loose")), anItem(.text("kept"), pinned: true)]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )
        #expect(spy.last.filters.kinds.first?.id == "pinned")

        controller.navigate(.up)
        controller.switchChipGroup()
        #expect(spy.last.filters.kinds.first?.isFocused == true)
        controller.activateFocused()
        #expect(spy.last.cards.map(\.preview) == [.text("kept")])
        #expect(spy.last.filters.kinds.first?.isActive == true)

        controller.toggleCategoryFilter("pinned")
        #expect(spy.last.cards.count == 2)
    }

    @Test func applying_retention_purges_expired_items_live() {
        let clock = FakeClock()
        let store = InMemoryHistoryStore()
        store.stored = [
            anItem(.text("fresh"), at: clock.now()),
            anItem(.text("stale"), at: clock.now().addingTimeInterval(-172_800)),
        ]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: clock, present: spy.record
        )
        #expect(spy.last.cards.count == 2)

        controller.applyRetention(RetentionPolicy(maxAge: 86_400))

        #expect(spy.last.cards.map(\.preview) == [.text("fresh")])
        #expect(store.stored.count == 1)
    }

    @Test func pin_and_delete_act_on_the_current_selection() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("first")), anItem(.text("second"))]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )

        controller.moveSelection(.next)
        controller.togglePinSelected()
        #expect(spy.last.cards[1].isPinned == true)

        controller.deleteSelected()
        #expect(spy.last.cards.map(\.preview) == [.text("first")])
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

extension ClipboardControllerBehaviour {
    @Test func the_paste_stack_pops_in_order_and_skips_deleted_items() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("first")), anItem(.text("second")), anItem(.text("third"))]
        let pasteboard = ScriptedPasteboard()
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: pasteboard, store: store, clock: FakeClock(), present: spy.record
        )

        controller.stackSelected()
        controller.moveSelection(.next)
        controller.stackSelected()
        controller.moveSelection(.next)
        controller.stackSelected()
        #expect(spy.last.stackCount == 3)

        let secondID = spy.last.cards[1].id
        controller.delete(secondID)
        #expect(spy.last.stackCount == 2)

        #expect(controller.popStack() == true)
        #expect(controller.popStack() == true)
        #expect(controller.popStack() == false)
        #expect(pasteboard.written == [.text("first"), .text("third")])
    }

    @Test func stacking_the_same_card_again_removes_it_from_the_stack() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("first")), anItem(.text("second"))]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )

        controller.stackSelected()
        #expect(spy.last.stackCount == 1)

        controller.stackSelected()
        #expect(spy.last.stackCount == 0)
        #expect(spy.last.cards[0].stackPosition == nil)
    }

    @Test func stacked_cards_carry_their_one_based_queue_position() {
        let store = InMemoryHistoryStore()
        store.stored = [anItem(.text("first")), anItem(.text("second")), anItem(.text("third"))]
        let spy = StateSpy()
        let controller = ClipboardController(
            pasteboard: ScriptedPasteboard(), store: store, clock: FakeClock(), present: spy.record
        )

        controller.moveSelection(.next)
        controller.stackSelected()
        controller.moveSelection(.previous)
        controller.stackSelected()

        #expect(spy.last.cards[1].stackPosition == 1)
        #expect(spy.last.cards[0].stackPosition == 2)
        #expect(spy.last.cards[2].stackPosition == nil)

        // Removing the first queued card promotes the ranks behind it.
        controller.moveSelection(.next)
        controller.stackSelected()
        #expect(spy.last.cards[0].stackPosition == 1)
        #expect(spy.last.cards[1].stackPosition == nil)
    }
}
