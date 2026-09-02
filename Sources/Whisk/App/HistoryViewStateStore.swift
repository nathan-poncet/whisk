import Combine
import Foundation

/// Bridges the presenter's output to SwiftUI observation. Frameworks ring:
/// nothing below the views knows this exists.
final class HistoryViewStateStore: ObservableObject {
    @Published private(set) var state: HistoryViewState = .empty
    @Published private(set) var focusRevision = 0
    @Published private(set) var closeRevision = 0

    func update(_ newState: HistoryViewState) {
        state = newState
    }

    func requestSearchFocus() {
        focusRevision += 1
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
    let highlight: (UUID) -> Void
    let activate: () -> Void
    let activatePlain: () -> Void
    let activateCard: (Int) -> Void
    let navigate: (ArrowDirection) -> Void
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
