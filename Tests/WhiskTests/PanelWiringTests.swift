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
        private(set) var system: [String] = []
        private(set) var editorOpenings = 0
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
                dragBegan: { [unowned self] in drags += 1 },
                system: PanelWiring.SystemActions(
                    openLink: { [unowned self] in system.append("open:\($0.absoluteString)") },
                    revealFiles: { [unowned self] in system.append("reveal:\($0.joined(separator: ","))") },
                    saveToDisk: { [unowned self] in system.append("save:\($0)") },
                    excludeSource: { [unowned self] bundleID, name in system.append("exclude:\(bundleID):\(name)") },
                    beginEditing: { [unowned self] _ in editorOpenings += 1 }))
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

    @Test func a_transformed_paste_closes_and_pastes_only_when_the_card_could_be_rewritten() throws {
        let fixture = Fixture([.text("alpha"), .image(Data([0x01]))])
        let text = fixture.spy.last.cards[0].id
        let image = fixture.spy.last.cards[1].id

        try fixture.wired.transform(text, .uppercase)
        try fixture.wired.transform(image, .uppercase)

        #expect(fixture.pasteboard.written == [.text("ALPHA")])
        #expect(fixture.hides == 1)
        #expect(fixture.pastes == 1)
    }

    @Test func copying_writes_and_closes_without_pasting_and_plain_pastes_strip_formatting() throws {
        let fixture = Fixture([.text("alpha")])
        let alpha = fixture.spy.last.cards[0].id

        try fixture.wired.copy(alpha)
        try fixture.wired.copySelected()
        try fixture.wired.selectPlain(alpha)

        #expect(fixture.pasteboard.written == [.text("alpha"), .text("alpha"), .text("alpha")])
        #expect(fixture.hides == 3)
        #expect(fixture.pastes == 1)
    }

    @Test func system_actions_close_the_panel_first_and_stack_and_source_deletion_reach_the_controller() throws {
        let url = try #require(URL(string: "https://example.com"))
        let fixture = Fixture([
            anItem(.link(url), from: "Safari", bundle: "com.apple.Safari"),
            anItem(.text("note"), from: "Notes", bundle: "com.apple.notes"),
            anItem(.text("kept"), from: "Notes", bundle: "com.apple.notes", pinned: true),
        ])
        let link = fixture.spy.last.cards[0].id

        try fixture.wired.openLink(url)
        try fixture.wired.revealFiles(["/tmp/a"])
        try fixture.wired.saveToDisk(.text("x"))
        try fixture.wired.excludeSource("com.apple.Safari", "Safari")
        try fixture.wired.stack(link)
        #expect(fixture.spy.last.stackCount == 1)
        try fixture.wired.deleteAllFromSource("com.apple.notes")

        #expect(fixture.hides == 3)
        #expect(fixture.pastes == 0)
        #expect(
            fixture.system == [
                "open:https://example.com", "reveal:/tmp/a", "save:text(\"x\")", "exclude:com.apple.Safari:Safari",
            ])
        #expect(fixture.spy.last.cards.map(\.preview) == [.link("https://example.com"), .text("kept")])
    }

    @Test func editing_flushes_the_query_and_rewrites_the_card_and_opening_the_editor_is_the_roots_call() throws {
        let fixture = Fixture([.text("alpha"), .text("beta")])
        let alpha = fixture.spy.last.cards[0]
        let beta = fixture.spy.last.cards[1].id

        try fixture.wired.search("bet")
        try fixture.wired.edit(beta, "gamma")
        try fixture.wired.beginEditing(alpha)

        #expect(fixture.spy.last.query == "bet")
        #expect(fixture.store.stored.map(\.payload) == [.text("alpha"), .text("gamma")])
        #expect(fixture.editorOpenings == 1)
        #expect(fixture.hides == 0)

        try fixture.wired.undo()

        #expect(fixture.store.stored.map(\.payload) == [.text("alpha"), .text("beta")])
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
