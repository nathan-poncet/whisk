import AppKit
import Carbon.HIToolbox
import Foundation
import Testing

@testable import Whisk

/// Records every panel action the router fires, as one line per call.
final class PanelActionSpy {
    private(set) var calls: [String] = []

    var actions: PanelActions {
        PanelActions(
            search: { [weak self] in self?.calls.append("search:\($0)") },
            select: { [weak self] in self?.calls.append("select:\($0)") },
            highlight: { [weak self] in self?.calls.append("highlight:\($0)") },
            activate: { [weak self] in self?.calls.append("activate") },
            activatePlain: { [weak self] in self?.calls.append("activatePlain") },
            activateCard: { [weak self] in self?.calls.append("activateCard:\($0)") },
            navigate: { [weak self] in self?.calls.append("navigate:\($0)") },
            jumpToEdge: { [weak self] in self?.calls.append("jump:\($0)") },
            switchChipGroup: { [weak self] in self?.calls.append("switchChipGroup") },
            toggleSourceFilter: { [weak self] in self?.calls.append("toggleSource:\($0)") },
            toggleCategoryFilter: { [weak self] in self?.calls.append("toggleCategory:\($0)") },
            focusSourceChip: { [weak self] in self?.calls.append("focusSource:\($0)") },
            focusCategoryChip: { [weak self] in self?.calls.append("focusCategory:\($0)") },
            togglePin: { [weak self] in self?.calls.append("togglePin:\($0)") },
            delete: { [weak self] in self?.calls.append("delete:\($0)") },
            dragBegan: { [weak self] in self?.calls.append("dragBegan") },
            togglePinSelected: { [weak self] in self?.calls.append("togglePinSelected") },
            deleteSelected: { [weak self] in self?.calls.append("deleteSelected") },
            stackSelected: { [weak self] in self?.calls.append("stackSelected") },
            panelWillShow: { [weak self] in self?.calls.append("panelWillShow") }
        )
    }
}

@MainActor
@Suite struct PanelKeyRouting {
    private final class Fixture {
        let spy = PanelActionSpy()
        let stateStore = HistoryViewStateStore()
        let keyBindings: KeyBindingsStore
        let vimBindings: VimBindingsStore
        let clock = FakeClock()
        private(set) var previewToggles = 0
        private(set) var closes = 0
        private(set) var router: PanelKeyRouter?
        private let sandbox: IsolatedDefaults

        init(vim: Bool) throws {
            sandbox = try IsolatedDefaults()
            keyBindings = KeyBindingsStore(defaults: sandbox.defaults)
            vimBindings = VimBindingsStore(defaults: sandbox.defaults)
            stateStore.configureInput(vim: vim, searchKey: vimBindings.key(for: .search))
            router = PanelKeyRouter(
                stateStore: stateStore, actions: spy.actions, keyBindings: keyBindings, vimBindings: vimBindings,
                togglePreview: { [unowned self] in previewToggles += 1 },
                closePanel: { [unowned self] in closes += 1 },
                now: { [unowned self] in clock.now() })
        }

        func press(_ keyCode: Int, _ modifiers: NSEvent.ModifierFlags = [], typing text: String = "") throws -> Bool {
            let event = try #require(aKeyEvent(keyCode, modifiers, typing: text))
            return try #require(router).handle(event)
        }
    }

    @Test func with_vim_off_the_users_bindings_route_the_panel_keys() throws {
        let fixture = try Fixture(vim: false)

        #expect(try fixture.press(kVK_Return, typing: "\r"))
        #expect(try fixture.press(kVK_Return, [.option], typing: "\r"))
        #expect(try fixture.press(kVK_Return, [.shift], typing: "\r"))
        #expect(try fixture.press(kVK_LeftArrow))
        #expect(try fixture.press(kVK_RightArrow))
        #expect(try fixture.press(kVK_UpArrow))
        #expect(try fixture.press(kVK_DownArrow))
        #expect(try fixture.press(kVK_Tab, [.control], typing: "\t"))
        #expect(try fixture.press(kVK_Delete, [.command]))
        #expect(!(try fixture.press(kVK_ANSI_Z, typing: "z")))

        #expect(
            fixture.spy.calls == [
                "activate", "activatePlain", "stackSelected", "navigate:left", "navigate:right", "navigate:up",
                "navigate:down", "switchChipGroup", "deleteSelected",
            ])
    }

    @Test func command_digits_paste_by_rail_position_and_other_chords_do_not() throws {
        let fixture = try Fixture(vim: false)

        #expect(try fixture.press(kVK_ANSI_1, [.command], typing: "1"))
        #expect(try fixture.press(kVK_ANSI_9, [.command], typing: "9"))
        #expect(!(try fixture.press(kVK_ANSI_0, [.command], typing: "0")))
        #expect(!(try fixture.press(kVK_ANSI_2, [.command, .option], typing: "2")))

        #expect(fixture.spy.calls == ["activateCard:0", "activateCard:8"])
    }

    @Test func keypad_enter_always_pastes_whatever_return_is_bound_to() throws {
        let fixture = try Fixture(vim: false)
        fixture.keyBindings.set(KeyBinding(keyCode: UInt16(kVK_ANSI_Y), modifiers: [.command]), for: .pasteSelection)

        #expect(try fixture.press(kVK_ANSI_KeypadEnter, typing: "\u{3}"))
        #expect(!(try fixture.press(kVK_Return, typing: "\r")))

        #expect(fixture.spy.calls == ["activate"])
    }

    @Test func a_space_bound_to_preview_stays_a_space_while_a_query_is_typed() throws {
        let fixture = try Fixture(vim: false)
        fixture.keyBindings.set(KeyBinding(keyCode: UInt16(kVK_Space), modifiers: []), for: .previewSelection)
        let presenter = HistoryPresenter()
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        fixture.stateStore.update(presenter.present(items: [], query: "abc", now: now))
        #expect(!(try fixture.press(kVK_Space, typing: " ")))
        #expect(fixture.previewToggles == 0)

        fixture.stateStore.update(presenter.present(items: [], query: "", now: now))
        #expect(try fixture.press(kVK_Space, typing: " "))
        #expect(fixture.previewToggles == 1)
    }

    @Test func vim_normal_mode_turns_letters_into_commands() throws {
        let fixture = try Fixture(vim: true)

        for (key, code) in [("h", kVK_ANSI_H), ("l", kVK_ANSI_L), ("k", kVK_ANSI_K), ("j", kVK_ANSI_J)] {
            #expect(try fixture.press(code, typing: key))
        }
        #expect(try fixture.press(kVK_ANSI_P, typing: "p"))
        #expect(try fixture.press(kVK_ANSI_P, [.shift], typing: "P"))
        #expect(try fixture.press(kVK_ANSI_M, typing: "m"))
        #expect(try fixture.press(kVK_ANSI_F, typing: "f"))
        #expect(try fixture.press(kVK_ANSI_G, [.shift], typing: "G"))
        #expect(try fixture.press(kVK_ANSI_C, typing: "c"))
        #expect(try fixture.press(kVK_ANSI_5, typing: "5"))
        #expect(try fixture.press(kVK_ANSI_V, typing: "v"))
        #expect(try fixture.press(kVK_ANSI_Q, typing: "q"))

        #expect(
            fixture.spy.calls == [
                "navigate:left", "navigate:right", "navigate:up", "navigate:down", "activate", "activatePlain",
                "stackSelected", "togglePinSelected", "jump:end", "search:", "activateCard:4",
            ])
        #expect(fixture.previewToggles == 1)
        #expect(fixture.closes == 1)
    }

    @Test func two_key_sequences_run_on_the_second_key_within_the_window() throws {
        let fixture = try Fixture(vim: true)

        #expect(try fixture.press(kVK_ANSI_G, typing: "g"))
        #expect(fixture.spy.calls.isEmpty)
        #expect(try fixture.press(kVK_ANSI_G, typing: "g"))
        #expect(fixture.spy.calls == ["jump:start"])

        #expect(try fixture.press(kVK_ANSI_D, typing: "d"))
        fixture.clock.advance(by: 2)
        #expect(try fixture.press(kVK_ANSI_D, typing: "d"))
        #expect(fixture.spy.calls == ["jump:start"])
        #expect(try fixture.press(kVK_ANSI_D, typing: "d"))
        #expect(fixture.spy.calls == ["jump:start", "deleteSelected"])

        #expect(try fixture.press(kVK_ANSI_G, typing: "g"))
        #expect(try fixture.press(kVK_ANSI_X, typing: "x"))
        #expect(fixture.spy.calls == ["jump:start", "deleteSelected"])
    }

    @Test func in_normal_mode_tab_switches_groups_slash_searches_and_chords_fall_through() throws {
        let fixture = try Fixture(vim: true)

        #expect(try fixture.press(kVK_Tab, typing: "\t"))
        #expect(try fixture.press(kVK_ANSI_Slash, typing: "/"))
        #expect(fixture.stateStore.searchActive)

        fixture.stateStore.setSearchActive(false)
        fixture.keyBindings.set(KeyBinding(keyCode: UInt16(kVK_ANSI_P), modifiers: [.command]), for: .pinSelection)
        #expect(try fixture.press(kVK_ANSI_P, [.command], typing: "p"))
        #expect(!(try fixture.press(kVK_F5, typing: "\u{F708}")))

        #expect(fixture.spy.calls == ["switchChipGroup", "togglePinSelected"])
    }

    @Test func in_vim_search_mode_return_commits_and_goes_back_to_normal() throws {
        let fixture = try Fixture(vim: true)
        fixture.stateStore.setSearchActive(true)

        #expect(try fixture.press(kVK_Return, typing: "\r"))

        #expect(!fixture.stateStore.searchActive)
        #expect(fixture.spy.calls.isEmpty)

        #expect(try fixture.press(kVK_ANSI_S, typing: "s"))
        #expect(fixture.stateStore.searchActive)
    }
}
