import Combine
import Foundation

/// Bridges the presenter's output to SwiftUI observation. Frameworks ring:
/// nothing below the views knows this exists.
final class HistoryViewStateStore: ObservableObject {
    @Published private(set) var state: HistoryViewState = .empty
    @Published private(set) var focusRevision = 0

    func update(_ newState: HistoryViewState) {
        state = newState
    }

    func requestSearchFocus() {
        focusRevision += 1
    }
}

/// Type-erased entry points into the controller, so views stay free of the
/// controller's gateway generics.
struct PanelActions {
    let search: (String) -> Void
    let select: (UUID) -> Void
    let highlight: (UUID) -> Void
    let activateSelected: () -> Void
    let moveSelection: (SelectionMove) -> Void
    let togglePin: (UUID) -> Void
    let delete: (UUID) -> Void
    let panelWillShow: () -> Void
}
