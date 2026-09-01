import AppKit
import Carbon.HIToolbox
import Combine

/// Everything the keyboard can do, each rebindable from Settings.
enum KeyAction: String, CaseIterable, Identifiable {
    case togglePanel
    case pasteSelection
    case previousCard
    case nextCard
    case rowUp
    case rowDown
    case pinSelection
    case deleteSelection

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .togglePanel: "Show / hide the panel"
        case .pasteSelection: "Paste the selection"
        case .previousCard: "Previous card or chip"
        case .nextCard: "Next card or chip"
        case .rowUp: "Focus the row above"
        case .rowDown: "Focus the row below"
        case .pinSelection: "Pin / unpin the selection"
        case .deleteSelection: "Delete the selection"
        }
    }

    /// Only the panel toggle is global; everything else acts inside the
    /// panel.
    var isGlobal: Bool {
        self == .togglePanel
    }
}

/// One recorded shortcut: a virtual key code plus device-independent
/// modifiers.
struct KeyBinding: Equatable, Codable {
    let keyCode: UInt16
    let rawModifiers: UInt

    var modifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: rawModifiers)
    }

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        rawModifiers = modifiers.intersection([.command, .option, .control, .shift]).rawValue
    }

    init(event: NSEvent) {
        self.init(keyCode: event.keyCode, modifiers: event.modifierFlags)
    }

    func matches(_ event: NSEvent) -> Bool {
        event.keyCode == keyCode
            && event.modifierFlags.intersection([.command, .option, .control, .shift]).rawValue == rawModifiers
    }

    var carbonModifiers: UInt32 {
        var carbon: UInt32 = 0
        if modifiers.contains(.command) { carbon |= UInt32(cmdKey) }
        if modifiers.contains(.shift) { carbon |= UInt32(shiftKey) }
        if modifiers.contains(.option) { carbon |= UInt32(optionKey) }
        if modifiers.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }
}

/// User-configured shortcuts, persisted per action; unset actions fall back
/// to defaults. The panel-toggle default resolves the character V through
/// the live keyboard layout, so it keeps following layout switches until
/// the user records something explicit.
final class KeyBindingsStore: ObservableObject {
    @Published private(set) var overrides: [String: KeyBinding] = [:]

    private let defaults: UserDefaults
    private static let storageKey = "keyBindings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
            let stored = try? JSONDecoder().decode([String: KeyBinding].self, from: data)
        {
            overrides = stored
        }
    }

    func binding(for action: KeyAction) -> KeyBinding {
        overrides[action.rawValue] ?? Self.defaultBinding(for: action)
    }

    func isCustomized(_ action: KeyAction) -> Bool {
        overrides[action.rawValue] != nil
    }

    func set(_ binding: KeyBinding, for action: KeyAction) {
        overrides[action.rawValue] = binding
        persist()
    }

    func reset(_ action: KeyAction) {
        overrides.removeValue(forKey: action.rawValue)
        persist()
    }

    func resetAll() {
        overrides = [:]
        persist()
    }

    /// Actions whose effective bindings collide with another action's.
    var duplicatedActions: [KeyAction] {
        let all = KeyAction.allCases.map { ($0, binding(for: $0)) }
        return all.filter { action, binding in
            all.contains { other, otherBinding in other != action && otherBinding == binding }
        }.map(\.0)
    }

    func label(for action: KeyAction) -> String {
        let binding = binding(for: action)
        var parts = ""
        if binding.modifiers.contains(.control) { parts += "⌃" }
        if binding.modifiers.contains(.option) { parts += "⌥" }
        if binding.modifiers.contains(.shift) { parts += "⇧" }
        if binding.modifiers.contains(.command) { parts += "⌘" }
        return parts + Self.keyLabel(binding.keyCode)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func defaultBinding(for action: KeyAction) -> KeyBinding {
        switch action {
        case .togglePanel:
            let keyCode = KeyboardLayout.keyCode(for: "v") ?? CGKeyCode(kVK_ANSI_V)
            return KeyBinding(keyCode: UInt16(keyCode), modifiers: [.command, .shift])
        case .pasteSelection:
            return KeyBinding(keyCode: UInt16(kVK_Return), modifiers: [])
        case .previousCard:
            return KeyBinding(keyCode: UInt16(kVK_LeftArrow), modifiers: [])
        case .nextCard:
            return KeyBinding(keyCode: UInt16(kVK_RightArrow), modifiers: [])
        case .rowUp:
            return KeyBinding(keyCode: UInt16(kVK_UpArrow), modifiers: [])
        case .rowDown:
            return KeyBinding(keyCode: UInt16(kVK_DownArrow), modifiers: [])
        case .pinSelection:
            let keyCode = KeyboardLayout.keyCode(for: "p") ?? CGKeyCode(kVK_ANSI_P)
            return KeyBinding(keyCode: UInt16(keyCode), modifiers: [.command])
        case .deleteSelection:
            return KeyBinding(keyCode: UInt16(kVK_Delete), modifiers: [.command])
        }
    }

    private static let specialKeyLabels: [UInt16: String] = [
        UInt16(kVK_Return): "⏎",
        UInt16(kVK_ANSI_KeypadEnter): "⌅",
        UInt16(kVK_Escape): "⎋",
        UInt16(kVK_Delete): "⌫",
        UInt16(kVK_ForwardDelete): "⌦",
        UInt16(kVK_Space): "␣",
        UInt16(kVK_Tab): "⇥",
        UInt16(kVK_LeftArrow): "←",
        UInt16(kVK_RightArrow): "→",
        UInt16(kVK_UpArrow): "↑",
        UInt16(kVK_DownArrow): "↓",
        UInt16(kVK_Home): "↖",
        UInt16(kVK_End): "↘",
        UInt16(kVK_PageUp): "⇞",
        UInt16(kVK_PageDown): "⇟",
    ]

    private static func keyLabel(_ keyCode: UInt16) -> String {
        if let special = specialKeyLabels[keyCode] {
            return special
        }
        if let character = KeyboardLayout.character(for: keyCode) {
            return String(character).uppercased()
        }
        return "key \(keyCode)"
    }
}
