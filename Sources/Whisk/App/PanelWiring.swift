import Foundation

/// Builds the panel's actions around the controller. Search keystrokes
/// coalesce through the debouncer, and anything that consumes the rail
/// flushes the pending query first, so no action lands on a stale state.
/// Closing the panel and pasting come in as closures — the composition
/// root's business, and what keeps this table testable without a window.
enum PanelWiring {
    static func actions<Board: Pasteboard, Time: Clock, Store: HistoryStore, Log: Logger>(
        for clipboard: ClipboardController<Board, Time, Store, Log>,
        searchDebounce: Debouncer,
        hidePanel: @escaping () -> Void,
        paste: @escaping () -> Void,
        dragBegan: @escaping () -> Void
    ) -> PanelActions {
        func consume(_ landed: Bool) {
            guard landed else { return }
            hidePanel()
            paste()
        }
        return PanelActions(
            search: { query in
                searchDebounce.schedule { clipboard.search(query) }
            },
            select: { id in
                searchDebounce.flush()
                clipboard.select(id)
                consume(true)
            },
            transform: { id, transform in
                searchDebounce.flush()
                consume(clipboard.select(id, transform: transform))
            },
            highlight: { clipboard.highlight($0) },
            activate: {
                searchDebounce.flush()
                consume(clipboard.activateFocused())
            },
            activatePlain: {
                searchDebounce.flush()
                consume(clipboard.activateFocused(plain: true))
            },
            activateCard: { index in
                searchDebounce.flush()
                consume(clipboard.activate(at: index))
            },
            navigate: { direction in
                searchDebounce.flush()
                clipboard.navigate(direction)
            },
            jumpToEdge: { edge in
                searchDebounce.flush()
                clipboard.jumpSelection(to: edge)
            },
            switchChipGroup: { clipboard.switchChipGroup() },
            toggleSourceFilter: { clipboard.toggleSourceFilter($0) },
            toggleCategoryFilter: { clipboard.toggleCategoryFilter($0) },
            focusSourceChip: { clipboard.focusSourceChip($0) },
            focusCategoryChip: { clipboard.focusCategoryChip($0) },
            togglePin: { clipboard.togglePin($0) },
            delete: { clipboard.delete($0) },
            dragBegan: dragBegan,
            togglePinSelected: { clipboard.togglePinSelected() },
            deleteSelected: {
                searchDebounce.flush()
                clipboard.deleteSelected()
            },
            stackSelected: {
                searchDebounce.flush()
                clipboard.stackSelected()
            },
            panelWillShow: {
                searchDebounce.cancel()
                clipboard.panelWillShow()
            }
        )
    }
}
