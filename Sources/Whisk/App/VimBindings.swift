import Foundation

/// The vim layer's editable keymap. A binding is what the keys type — one
/// or two characters; a two-character binding (gg, dd) runs on the double
/// tap. Matching by typed character keeps every layout native. Esc, Tab,
/// the / alias and the 1–9 direct pastes are fixed.
enum VimAction: String, CaseIterable, Identifiable {
    case previousCard
    case nextCard
    case rowUp
    case rowDown
    case firstCard
    case lastCard
    case paste
    case pastePlain
    case preview
    case stackToggle
    case pinToggle
    case deleteSelection
    case search
    case clearSearch
    case closePanel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .previousCard: localized("Previous card or chip")
        case .nextCard: localized("Next card or chip")
        case .rowUp: localized("Focus the row above")
        case .rowDown: localized("Focus the row below")
        case .firstCard: localized("First card")
        case .lastCard: localized("Last card")
        case .paste: localized("Paste the selection")
        case .pastePlain: localized("Paste as plain text")
        case .preview: localized("Preview the selection")
        case .stackToggle: localized("Toggle the selection in the paste stack")
        case .pinToggle: localized("Pin / unpin the selection")
        case .deleteSelection: localized("Delete the selection")
        case .search: localized("Start a search")
        case .clearSearch: localized("Clear the search")
        case .closePanel: localized("Close the panel")
        }
    }

    var defaultKey: String {
        switch self {
        case .previousCard: "h"
        case .nextCard: "l"
        case .rowUp: "k"
        case .rowDown: "j"
        case .firstCard: "gg"
        case .lastCard: "G"
        case .paste: "p"
        case .pastePlain: "P"
        case .preview: "v"
        case .stackToggle: "m"
        case .pinToggle: "f"
        case .deleteSelection: "dd"
        case .search: "s"
        case .clearSearch: "c"
        case .closePanel: "q"
        }
    }
}

/// Persists only the customized bindings; everything else follows the
/// defaults, so new actions pick their key up automatically.
final class VimBindingsStore: ObservableObject {
    @Published private(set) var keys: [VimAction: String]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.dictionary(forKey: "vimBindings") as? [String: String] ?? [:]
        var map: [VimAction: String] = [:]
        for action in VimAction.allCases {
            map[action] = stored[action.rawValue] ?? action.defaultKey
        }
        keys = map
    }

    func key(for action: VimAction) -> String {
        keys[action] ?? action.defaultKey
    }

    /// One or two printable characters; anything else falls back to the
    /// action's default.
    func set(_ key: String, for action: VimAction) {
        let trimmed = String(key.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2))
        keys[action] = trimmed.isEmpty ? action.defaultKey : trimmed
        persist()
    }

    func reset(_ action: VimAction) {
        keys[action] = action.defaultKey
        persist()
    }

    func isCustomized(_ action: VimAction) -> Bool {
        key(for: action) != action.defaultKey
    }

    var duplicatedActions: Set<VimAction> {
        var seen: [String: VimAction] = [:]
        var duplicates: Set<VimAction> = []
        for action in VimAction.allCases {
            let key = key(for: action)
            if let other = seen[key] {
                duplicates.insert(other)
                duplicates.insert(action)
            } else {
                seen[key] = action
            }
        }
        return duplicates
    }

    /// True when some binding starts with this character but needs more.
    func isSequencePrefix(_ character: String) -> Bool {
        keys.values.contains { $0.count == 2 && $0.hasPrefix(character) && $0 != character }
    }

    func action(for key: String) -> VimAction? {
        VimAction.allCases.first { self.key(for: $0) == key }
    }

    private func persist() {
        var stored: [String: String] = [:]
        for (action, key) in keys where key != action.defaultKey {
            stored[action.rawValue] = key
        }
        defaults.set(stored, forKey: "vimBindings")
    }
}
