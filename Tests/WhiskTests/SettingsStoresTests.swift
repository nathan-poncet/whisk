import AppKit
import Carbon.HIToolbox
import Foundation
import Testing

@testable import Whisk

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

    @Test func capacity_labels_read_naturally() {
        #expect(GeneralSettingsStore.capacityLabel(0) == localized("Unlimited"))
        #expect(["500 items", "500 éléments"].contains(GeneralSettingsStore.capacityLabel(500)))
    }
}
