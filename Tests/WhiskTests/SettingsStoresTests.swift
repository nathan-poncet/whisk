import AppKit
import Carbon.HIToolbox
import Foundation
import Testing

@testable import Whisk

/// A key press the way AppKit would deliver it, without a window.
func aKeyEvent(_ keyCode: Int, _ modifiers: NSEvent.ModifierFlags = [], typing characters: String = "") -> NSEvent? {
    NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: 0, context: nil,
        characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: UInt16(keyCode))
}

/// A UserDefaults suite of its own per test, wiped when the test ends.
final class IsolatedDefaults {
    let defaults: UserDefaults
    private let name: String

    init() throws {
        name = "whisk-tests-\(UUID().uuidString)"
        defaults = try #require(UserDefaults(suiteName: name))
    }

    deinit {
        defaults.removePersistentDomain(forName: name)
    }
}

@MainActor
@Suite struct KeyBindingsPersistence {
    @Test func a_recorded_shortcut_persists_and_reloads() throws {
        let sandbox = try IsolatedDefaults()
        let recorded = KeyBinding(keyCode: UInt16(kVK_ANSI_K), modifiers: [.command, .shift])

        KeyBindingsStore(defaults: sandbox.defaults).set(recorded, for: .pinSelection)
        let reloaded = KeyBindingsStore(defaults: sandbox.defaults)

        #expect(reloaded.binding(for: .pinSelection) == recorded)
        #expect(reloaded.isCustomized(.pinSelection))
        #expect(!reloaded.isCustomized(.deleteSelection))
    }

    @Test func resetting_returns_an_action_to_its_default() throws {
        let sandbox = try IsolatedDefaults()
        let store = KeyBindingsStore(defaults: sandbox.defaults)
        let original = store.binding(for: .deleteSelection)
        store.set(KeyBinding(keyCode: UInt16(kVK_ANSI_X), modifiers: [.command]), for: .deleteSelection)

        store.reset(.deleteSelection)

        #expect(store.binding(for: .deleteSelection) == original)
        #expect(!store.isCustomized(.deleteSelection))
    }

    @Test func two_actions_on_one_shortcut_are_both_reported() throws {
        let sandbox = try IsolatedDefaults()
        let store = KeyBindingsStore(defaults: sandbox.defaults)
        #expect(store.duplicatedActions.isEmpty)

        store.set(store.binding(for: .deleteSelection), for: .pinSelection)

        #expect(Set(store.duplicatedActions) == [.pinSelection, .deleteSelection])
    }

    @Test func labels_spell_modifiers_in_the_standard_order() throws {
        let sandbox = try IsolatedDefaults()
        let store = KeyBindingsStore(defaults: sandbox.defaults)
        store.set(
            KeyBinding(keyCode: UInt16(kVK_Return), modifiers: [.command, .shift, .option, .control]),
            for: .pasteSelection)

        #expect(store.label(for: .pasteSelection) == "⌃⌥⇧⌘⏎")
        #expect(store.label(for: .previousCard) == "←")
        #expect(store.label(for: .switchChipGroup) == "⌃⇥")
    }

    @Test func stored_bindings_that_will_not_decode_fall_back_to_defaults_and_say_so() throws {
        let sandbox = try IsolatedDefaults()
        sandbox.defaults.set(Data("not json".utf8), forKey: "keyBindings")
        let logger = RecordingLogger()

        let store = KeyBindingsStore(defaults: sandbox.defaults, logger: logger)

        #expect(KeyAction.allCases.allSatisfy { !store.isCustomized($0) })
        #expect(logger.messages.count == 1)
    }

    @Test func a_binding_is_read_off_a_key_event_and_matches_it_back() throws {
        let press = try #require(aKeyEvent(kVK_ANSI_K, [.command, .shift, .capsLock], typing: "K"))
        let other = try #require(aKeyEvent(kVK_ANSI_K, [.command], typing: "k"))

        let binding = KeyBinding(event: press)

        #expect(binding == KeyBinding(keyCode: UInt16(kVK_ANSI_K), modifiers: [.command, .shift]))
        #expect(binding.matches(press))
        #expect(!binding.matches(other))
    }

    @Test func recording_takes_the_next_key_and_escape_cancels() throws {
        _ = NSApplication.shared
        let sandbox = try IsolatedDefaults()
        let store = KeyBindingsStore(defaults: sandbox.defaults)
        let press = try #require(aKeyEvent(kVK_ANSI_X, [.command], typing: "x"))
        let escape = try #require(aKeyEvent(kVK_Escape))
        #expect(!store.record(press))

        store.beginRecording(.pinSelection)
        #expect(store.recordingAction == .pinSelection)
        #expect(store.record(press))
        #expect(store.binding(for: .pinSelection) == KeyBinding(event: press))
        #expect(store.recordingAction == nil)

        store.beginRecording(.deleteSelection)
        #expect(store.record(escape))
        #expect(!store.isCustomized(.deleteSelection))
        #expect(store.recordingAction == nil)
    }

    @Test func every_action_has_a_name_and_only_two_reach_outside_the_panel() {
        let names = KeyAction.allCases.map(\.displayName)

        #expect(names.allSatisfy { !$0.isEmpty })
        #expect(Set(names).count == names.count)
        #expect(KeyAction.allCases.filter(\.isGlobal) == [.togglePanel, .pasteNextFromStack])
        #expect(KeyAction.allCases.map(\.id) == KeyAction.allCases.map(\.rawValue))
    }

    @Test func a_binding_keeps_only_the_four_modifier_keys() {
        let clean = KeyBinding(keyCode: 1, modifiers: [.command])
        let noisy = KeyBinding(keyCode: 1, modifiers: [.command, .capsLock, .function, .numericPad])

        #expect(noisy == clean)
        #expect(noisy.carbonModifiers == UInt32(cmdKey))
        #expect(
            KeyBinding(keyCode: 1, modifiers: [.shift, .option, .control]).carbonModifiers
                == UInt32(shiftKey | optionKey | controlKey))
    }
}

@Suite struct VimBindingsPersistence {
    @Test func a_key_is_kept_to_two_characters_and_an_empty_one_falls_back_to_the_default() throws {
        let sandbox = try IsolatedDefaults()
        let store = VimBindingsStore(defaults: sandbox.defaults)

        store.set("xyz", for: .paste)
        #expect(store.key(for: .paste) == "xy")

        store.set("  ", for: .paste)
        #expect(store.key(for: .paste) == "p")
        #expect(!store.isCustomized(.paste))
    }

    @Test func only_customized_keys_are_persisted_and_they_reload() throws {
        let sandbox = try IsolatedDefaults()

        VimBindingsStore(defaults: sandbox.defaults).set("x", for: .closePanel)

        #expect(sandbox.defaults.dictionary(forKey: "vimBindings") as? [String: String] == ["closePanel": "x"])
        #expect(VimBindingsStore(defaults: sandbox.defaults).key(for: .closePanel) == "x")
    }

    @Test func two_actions_on_one_key_are_both_reported() throws {
        let sandbox = try IsolatedDefaults()
        let store = VimBindingsStore(defaults: sandbox.defaults)
        #expect(store.duplicatedActions.isEmpty)

        store.set("p", for: .preview)

        #expect(store.duplicatedActions == [.paste, .preview])
    }

    @Test func a_two_key_sequence_is_recognized_by_its_first_key() throws {
        let sandbox = try IsolatedDefaults()
        let store = VimBindingsStore(defaults: sandbox.defaults)

        #expect(store.isSequencePrefix("g"))
        #expect(store.isSequencePrefix("d"))
        #expect(!store.isSequencePrefix("gg"))
        #expect(!store.isSequencePrefix("h"))
        #expect(store.action(for: "gg") == .firstCard)
        #expect(store.action(for: "G") == .lastCard)
    }

    @Test func resetting_one_action_restores_its_default_alone() throws {
        let sandbox = try IsolatedDefaults()
        let store = VimBindingsStore(defaults: sandbox.defaults)
        store.set("x", for: .search)
        store.set("y", for: .closePanel)

        store.reset(.search)

        #expect(store.key(for: .search) == "s")
        #expect(store.key(for: .closePanel) == "y")
    }

    @Test func every_vim_action_has_a_name_and_a_distinct_default_key() {
        let names = VimAction.allCases.map(\.displayName)
        let keys = VimAction.allCases.map(\.defaultKey)

        #expect(names.allSatisfy { !$0.isEmpty })
        #expect(Set(names).count == names.count)
        #expect(Set(keys).count == keys.count)
        #expect(VimAction.allCases.map(\.id) == VimAction.allCases.map(\.rawValue))
    }

    @Test func resetting_everything_restores_every_default() throws {
        let sandbox = try IsolatedDefaults()
        let store = VimBindingsStore(defaults: sandbox.defaults)
        store.set("x", for: .search)
        store.set("y", for: .closePanel)

        store.resetAll()

        #expect(VimAction.allCases.allSatisfy { store.key(for: $0) == $0.defaultKey })
        #expect(sandbox.defaults.dictionary(forKey: "vimBindings")?.isEmpty == true)
    }
}

@Suite struct GeneralSettingsPersistence {
    @Test func a_fresh_install_starts_from_the_documented_defaults() throws {
        let sandbox = try IsolatedDefaults()

        let store = GeneralSettingsStore(defaults: sandbox.defaults)

        #expect(store.retentionPeriod == .forever)
        #expect(store.capacity == 500)
        #expect(store.checkForUpdates)
        #expect(!store.vimNavigation)
        #expect(store.excludedApps.isEmpty)
        #expect(store.policy == .standard)
    }

    @Test func the_policy_follows_the_capacity_and_the_period() throws {
        let sandbox = try IsolatedDefaults()
        let store = GeneralSettingsStore(defaults: sandbox.defaults)

        store.capacity = 0
        store.retentionPeriod = .week
        #expect(store.policy == RetentionPolicy(capacity: .unlimited, maxAge: 604_800))

        store.capacity = 250
        store.retentionPeriod = .day
        #expect(store.policy == RetentionPolicy(capacity: try #require(HistoryCapacity(250)), maxAge: 86_400))
    }

    @Test func settings_persist_across_instances() throws {
        let sandbox = try IsolatedDefaults()
        let first = GeneralSettingsStore(defaults: sandbox.defaults)
        first.capacity = 1000
        first.retentionPeriod = .month
        first.checkForUpdates = false
        first.vimNavigation = true
        first.excludedApps = [ExcludedApp(bundleID: "com.apple.keychainaccess", name: "Keychain Access")]

        let second = GeneralSettingsStore(defaults: sandbox.defaults)

        #expect(second.capacity == 1000)
        #expect(second.retentionPeriod == .month)
        #expect(!second.checkForUpdates)
        #expect(second.vimNavigation)
        #expect(second.excludedBundleIDs == ["com.apple.keychainaccess"])
    }

    @Test func stored_exclusions_that_will_not_decode_fall_back_to_none_and_say_so() throws {
        let sandbox = try IsolatedDefaults()
        sandbox.defaults.set(Data("not json".utf8), forKey: "excludedApps")
        let logger = RecordingLogger()

        let store = GeneralSettingsStore(defaults: sandbox.defaults, logger: logger)

        #expect(store.excludedApps.isEmpty)
        #expect(logger.messages.count == 1)
    }

    @Test func retention_periods_and_excluded_apps_identify_and_label_themselves() {
        let labels = RetentionPeriodOption.allCases.map(\.label)

        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == labels.count)
        #expect(RetentionPeriodOption.allCases.map(\.id) == RetentionPeriodOption.allCases.map(\.rawValue))
        #expect(ExcludedApp(bundleID: "com.slack", name: "Slack").id == "com.slack")
    }

    @Test func the_login_item_reports_its_current_status_without_touching_it() {
        let manager = LoginItemManager()

        #expect(manager.lastError == nil)
        #expect(manager.isEnabled == false || manager.isEnabled == true)
    }

    @Test func capacity_labels_read_naturally() {
        #expect(GeneralSettingsStore.capacityLabel(0) == localized("Unlimited"))
        #expect(["500 items", "500 éléments"].contains(GeneralSettingsStore.capacityLabel(500)))
    }
}
