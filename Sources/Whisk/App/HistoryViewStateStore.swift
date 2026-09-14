import Combine
import Foundation

/// Bridges the presenter's output to SwiftUI observation. Frameworks ring:
/// nothing below the views knows this exists.
final class HistoryViewStateStore: ObservableObject {
    @Published private(set) var state: HistoryViewState = .empty
    @Published private(set) var focusRevision = 0
    @Published private(set) var closeRevision = 0

    /// Vim navigation splits the panel into two input modes: SEARCH is the
    /// field with focus, NORMAL frees the letters to act as commands. With
    /// vim off the panel simply never leaves SEARCH. The search key rides
    /// along so hints always show the actual binding.
    @Published private(set) var vimEnabled = false
    @Published private(set) var searchActive = true
    @Published private(set) var vimSearchKey = "s"

    /// The card whose text is being edited in the panel, while it is, and
    /// the text as it stands — here rather than in the view, so the key
    /// router can save it on Return.
    @Published private(set) var editing: CardViewState?
    @Published private(set) var editingText = ""

    func beginEditing(_ card: CardViewState) {
        guard card.transformable else { return }
        editingText = Self.editableText(of: card)
        editing = card
    }

    func setEditingText(_ text: String) {
        editingText = text
    }

    func endEditing() {
        editing = nil
        editingText = ""
    }

    /// What the editor starts from: the card's text, or a link's address.
    static func editableText(of card: CardViewState) -> String {
        switch card.dragPayload {
        case .text(let value): return value
        case .link(let url): return url.absoluteString
        case .image, .files: return ""
        }
    }

    /// The card's side in points; the selected card grows by the zoom.
    @Published private(set) var cardSide: CGFloat = 200
    static let selectionZoom: CGFloat = 1.05
    /// The room the rail gives one card: the zoomed slot plus the gap.
    static let cardGap: CGFloat = 14

    var zoomedCardSide: CGFloat {
        cardSide * Self.selectionZoom
    }

    var cardStride: CGFloat {
        zoomedCardSide + Self.cardGap
    }

    func configureCards(side: CGFloat) {
        cardSide = side
    }

    func update(_ newState: HistoryViewState) {
        state = newState
    }

    func requestSearchFocus() {
        focusRevision += 1
    }

    func configureInput(vim: Bool, searchKey: String) {
        vimEnabled = vim
        searchActive = !vim
        vimSearchKey = searchKey
    }

    func setSearchActive(_ active: Bool) {
        guard active != searchActive else { return }
        searchActive = active
    }

    /// One cursor at a time: while vim's search mode holds it, neither a
    /// card nor a chip may wear one. With vim off the field never holds a
    /// cursor of its own.
    var cursorOnSearch: Bool {
        vimEnabled && searchActive
    }

    /// The capsule stays folded while it has nothing to show: it stretches
    /// on the first typed character, or the moment vim's search mode
    /// engages, even empty.
    func searchExpanded(typed text: String) -> Bool {
        !text.isEmpty || cursorOnSearch
    }

    /// The panel just went away: the rail rewinds to its leading edge
    /// while nobody is looking, so every open starts at position zero
    /// with no visible travel.
    func panelDidClose() {
        closeRevision += 1
    }
}

/// Type-erased entry points into the controller, so views stay free of the
/// controller's gateway generics.
struct PanelActions {
    let search: (String) -> Void
    let select: (UUID) -> Void
    let selectPlain: (UUID) -> Void
    /// Puts the card on the pasteboard and closes, without pasting.
    let copy: (UUID) -> Void
    let copySelected: () -> Void
    let transform: (UUID, TextTransform) -> Void
    let openLink: (URL) -> Void
    let revealFiles: ([String]) -> Void
    let saveToDisk: (DragPayload) -> Void
    let stack: (UUID) -> Void
    let excludeSource: (_ bundleID: String, _ name: String) -> Void
    let deleteAllFromSource: (String) -> Void
    let beginEditing: (CardViewState) -> Void
    let edit: (UUID, String) -> Void
    let undo: () -> Void
    let highlight: (UUID) -> Void
    let activate: () -> Void
    let activatePlain: () -> Void
    let activateCard: (Int) -> Void
    let navigate: (ArrowDirection) -> Void
    let jumpToEdge: (SelectionEdge) -> Void
    let switchChipGroup: () -> Void
    let toggleSourceFilter: (String) -> Void
    let toggleCategoryFilter: (String) -> Void
    let focusSourceChip: (String) -> Void
    let focusCategoryChip: (String) -> Void
    let togglePin: (UUID) -> Void
    let delete: (UUID) -> Void
    let dragBegan: () -> Void
    let togglePinSelected: () -> Void
    let deleteSelected: () -> Void
    let stackSelected: () -> Void
    let panelWillShow: () -> Void
}
