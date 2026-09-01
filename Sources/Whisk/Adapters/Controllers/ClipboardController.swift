import Foundation

/// One step of keyboard navigation through the visible cards.
enum SelectionMove {
    case previous
    case next
}

/// Which region of the panel the keyboard is steering.
enum PanelZone {
    case apps
    case kinds
    case cards
}

/// A key-arrow press, routed by the controller to a zone change (up/down)
/// or a move within the focused zone (left/right).
enum ArrowDirection {
    case up
    case down
    case left
    case right
}

/// The rail renders eagerly (lazy loading pops cards in during fast
/// scrolls), so it is bounded; search reaches everything beyond it.
private let railLimit = 60

/// The pinned filter lives in the kind-chip row without being a content
/// category; controller navigation and presenter rendering share this id.
let pinnedChipID = "pinned"

/// Translates UI and OS events into use case invocations and hands each
/// result to the presenter. Owns the current history, search query and
/// keyboard selection; generic over its gateways, like the use cases it
/// drives. A storage failure is logged and the in-memory state keeps
/// working.
final class ClipboardController<Board: Pasteboard, Time: Clock, Store: HistoryStore> {
    private var history: History
    private var query = ""
    private var activeSourceKey: String?
    private var activeCategory: ContentCategory?
    private var pinnedOnly = false
    private var retention = RetentionPolicy.standard
    private var isPaused = false
    private var excludedBundleIDs: Set<String> = []
    private var selectedID: UUID?
    private var focusZone: PanelZone = .cards
    private var focusedAppIndex = 0
    private var focusedKindIndex = 0

    private let capture: CaptureClipboardChange<Board, Time, Store>
    private let selectItem: SelectItem<Board, Time, Store>
    private let togglePinItem: TogglePin<Store>
    private let deleteItem: DeleteItem<Store>
    private let clearUnpinned: ClearHistory<Store>
    private let enforceRetention: EnforceRetention<Store>
    private let filterHistory = FilterHistory()
    private let presenter: HistoryPresenter
    private let clock: Time
    private let pasteboard: Board
    private let present: (HistoryViewState) -> Void

    init(
        pasteboard: Board,
        store: Store,
        clock: Time,
        presenter: HistoryPresenter = HistoryPresenter(),
        present: @escaping (HistoryViewState) -> Void
    ) {
        self.clock = clock
        self.presenter = presenter
        self.pasteboard = pasteboard
        self.present = present
        capture = CaptureClipboardChange(pasteboard: pasteboard, clock: clock, store: store)
        selectItem = SelectItem(pasteboard: pasteboard, clock: clock, store: store)
        togglePinItem = TogglePin(store: store)
        deleteItem = DeleteItem(store: store)
        clearUnpinned = ClearHistory(store: store)
        enforceRetention = EnforceRetention(store: store)
        do {
            history = try LoadHistory(store: store)()
        } catch {
            NSLog("Whisk: could not load history — %@", String(describing: error))
            history = History()
        }
        refresh()
    }

    func pollTick() {
        if isPaused {
            // Consume changes so nothing copied during the pause is
            // retro-captured on resume.
            _ = pasteboard.readIfChanged()
        } else {
            mutate { try capture(into: $0, excluding: excludedBundleIDs) }
        }
        guard retention.maxAge != nil else { return }
        enforceRetentionNow()
    }

    /// Suspends or resumes capture; everything else keeps working.
    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    /// Applications whose copies must never be recorded.
    func applyExclusions(_ bundleIDs: Set<String>) {
        excludedBundleIDs = bundleIDs
    }

    /// Applies a new retention policy immediately and keeps enforcing it.
    func applyRetention(_ policy: RetentionPolicy) {
        retention = policy
        enforceRetentionNow()
        refresh()
    }

    private func enforceRetentionNow() {
        let previous = history
        do {
            history = try enforceRetention(history, policy: retention, now: clock.now())
        } catch {
            NSLog("Whisk: storage failure — %@", String(describing: error))
        }
        guard history != previous else { return }
        refresh()
    }

    /// Pastes the card at a rail position (⌘1…⌘9). Returns false when the
    /// position is empty.
    @discardableResult
    func activate(at index: Int) -> Bool {
        let items = visibleItems
        guard items.indices.contains(index) else { return false }
        select(items[index].id)
        return true
    }

    func search(_ newQuery: String) {
        query = newQuery
        selectedID = nil
        refresh()
    }

    /// Filters the rail to one source application; toggling the active
    /// chip clears it.
    func toggleSourceFilter(_ key: String) {
        activeSourceKey = activeSourceKey == key ? nil : key
        selectedID = nil
        refresh()
    }

    /// Filters the rail to one content category — or to pinned items when
    /// given the pinned chip; toggling the active chip clears it.
    func toggleCategoryFilter(_ rawCategory: String) {
        if rawCategory == pinnedChipID {
            pinnedOnly.toggle()
            selectedID = nil
            refresh()
            return
        }
        guard let category = ContentCategory(rawValue: rawCategory) else { return }
        activeCategory = activeCategory == category ? nil : category
        selectedID = nil
        refresh()
    }

    func select(_ id: UUID, plain: Bool = false) {
        mutate { try selectItem(id, in: $0, plain: plain) }
    }

    /// Moves the keyboard selection through the visible cards, clamped at
    /// both ends.
    func moveSelection(_ step: SelectionMove) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        guard let current = selectedID,
            let index = items.firstIndex(where: { $0.id == current })
        else {
            selectedID = items.first?.id
            refresh()
            return
        }
        let destination = step == .next ? min(index + 1, items.count - 1) : max(index - 1, 0)
        selectedID = items[destination].id
        refresh()
    }

    /// Moves the keyboard selection onto a specific visible card, e.g. the
    /// one under the pointer. Selects only — nothing is written back.
    func highlight(_ id: UUID) {
        guard id != selectedID || focusZone != .cards else { return }
        guard visibleItems.contains(where: { $0.id == id }) else { return }
        selectedID = id
        focusZone = .cards
        refresh()
    }

    /// Moves the keyboard focus onto a specific app chip, e.g. the one
    /// under the pointer — the mouse and the arrows share one focus.
    func focusSourceChip(_ key: String) {
        guard let index = distinctSources.firstIndex(where: { $0.filterKey == key }) else { return }
        guard focusZone != .apps || focusedAppIndex != index else { return }
        focusZone = .apps
        focusedAppIndex = index
        refresh()
    }

    /// Moves the keyboard focus onto a specific kind chip.
    func focusCategoryChip(_ chipID: String) {
        guard let index = kindChipIDs.firstIndex(of: chipID) else { return }
        guard focusZone != .kinds || focusedKindIndex != index else { return }
        focusZone = .kinds
        focusedKindIndex = index
        refresh()
    }

    /// Up and down move between the chip rows and the rail; left and right
    /// move within whichever zone holds the focus.
    func navigate(_ direction: ArrowDirection) {
        switch direction {
        case .left, .right:
            navigateHorizontally(direction == .right ? 1 : -1)
        case .up:
            if focusZone == .cards {
                focusZone = distinctSources.isEmpty ? (kindChipIDs.isEmpty ? .cards : .kinds) : .apps
            }
            refresh()
        case .down:
            focusZone = .cards
            refresh()
        }
    }

    /// Jumps between the app group and the kind group of the chip row —
    /// the fast lane next to arrowing across the separator.
    func switchChipGroup() {
        let hasApps = !distinctSources.isEmpty
        let hasKinds = !kindChipIDs.isEmpty
        switch focusZone {
        case .apps:
            if hasKinds { focusZone = .kinds }
        case .kinds:
            if hasApps { focusZone = .apps }
        case .cards:
            if hasApps {
                focusZone = .apps
            } else if hasKinds {
                focusZone = .kinds
            }
        }
        refresh()
    }

    // The two chip groups share one visual row: arrowing past a group's
    // edge crosses the separator into the other group.
    private func navigateHorizontally(_ step: Int) {
        switch focusZone {
        case .cards:
            moveSelection(step > 0 ? .next : .previous)
        case .apps:
            let destination = focusedAppIndex + step
            if destination >= distinctSources.count, !kindChipIDs.isEmpty {
                focusZone = .kinds
                focusedKindIndex = 0
            } else {
                focusedAppIndex = max(0, min(destination, distinctSources.count - 1))
            }
            refresh()
        case .kinds:
            let destination = focusedKindIndex + step
            if destination < 0, !distinctSources.isEmpty {
                focusZone = .apps
                focusedAppIndex = distinctSources.count - 1
            } else {
                focusedKindIndex = max(0, min(destination, kindChipIDs.count - 1))
            }
            refresh()
        }
    }

    /// Acts on whatever holds the keyboard focus. Returns true only when a
    /// card was put back on the pasteboard — the caller closes the panel
    /// then, and stays open for chip toggles.
    @discardableResult
    func activateFocused(plain: Bool = false) -> Bool {
        switch focusZone {
        case .cards:
            return activateSelected(plain: plain)
        case .apps:
            let sources = distinctSources
            guard sources.indices.contains(focusedAppIndex) else { return false }
            toggleSourceFilter(sources[focusedAppIndex].filterKey)
            return false
        case .kinds:
            let chips = kindChipIDs
            guard chips.indices.contains(focusedKindIndex) else { return false }
            toggleCategoryFilter(chips[focusedKindIndex])
            return false
        }
    }

    /// Puts the highlighted card back on the pasteboard; the first visible
    /// card counts as highlighted until the selection is stepped.
    @discardableResult
    func activateSelected(plain: Bool = false) -> Bool {
        guard let id = selectedID ?? visibleItems.first?.id else { return false }
        select(id, plain: plain)
        return true
    }

    func togglePin(_ id: UUID) {
        mutate { try togglePinItem(id, in: $0) }
    }

    func togglePinSelected() {
        guard let id = selectedID else { return }
        togglePin(id)
    }

    func delete(_ id: UUID) {
        mutate { try deleteItem(id, in: $0) }
    }

    func deleteSelected() {
        guard let id = selectedID else { return }
        delete(id)
    }

    func clear() {
        mutate { try clearUnpinned($0) }
    }

    func panelWillShow() {
        query = ""
        activeSourceKey = nil
        activeCategory = nil
        pinnedOnly = false
        selectedID = nil
        focusZone = .cards
        focusedAppIndex = 0
        focusedKindIndex = 0
        refresh()
    }

    // One chip per application: deduplicated leniently (items recorded
    // before bundle ids existed carry a name only), preferring the variant
    // that has a bundle id so the chip gets an icon.
    private var distinctSources: [SourceApp] {
        var chips: [SourceApp] = []
        for item in history.items {
            guard let source = item.source else { continue }
            if let index = chips.firstIndex(where: { $0.matches(source) }) {
                if chips[index].bundleID == nil, source.bundleID != nil {
                    chips[index] = source
                }
            } else {
                chips.append(source)
            }
        }
        return chips
    }

    private var presentCategories: [ContentCategory] {
        let present = Set(history.items.map(\.category))
        return ContentCategory.allCases.filter(present.contains)
    }

    private var hasPinned: Bool {
        history.items.contains(where: \.isPinned)
    }

    // Mirrors the presenter's chip ordering — pinned first, then the
    // categories — so keyboard indices land on what is drawn.
    private var kindChipIDs: [String] {
        (hasPinned ? [pinnedChipID] : []) + presentCategories.map(\.rawValue)
    }

    private func currentFilter(sources: [SourceApp]) -> HistoryFilter {
        HistoryFilter(
            query: query,
            source: sources.first { $0.filterKey == activeSourceKey },
            category: activeCategory,
            pinnedOnly: pinnedOnly
        )
    }

    private var visibleItems: [ClipboardItem] {
        let matches = filterHistory(history, filter: currentFilter(sources: distinctSources))
        return Array(matches.prefix(railLimit))
    }

    private func mutate(_ transform: (History) throws -> History) {
        let previous = history
        do {
            history = try transform(history)
        } catch {
            NSLog("Whisk: storage failure — %@", String(describing: error))
        }
        guard history != previous else { return }
        refresh()
    }

    private func refresh() {
        let sources = distinctSources
        if let key = activeSourceKey, !sources.contains(where: { $0.filterKey == key }) {
            activeSourceKey = nil
        }
        let categories = presentCategories
        if let category = activeCategory, !categories.contains(category) {
            activeCategory = nil
        }
        if pinnedOnly, !hasPinned {
            pinnedOnly = false
        }
        let chips = kindChipIDs
        focusedAppIndex = max(0, min(focusedAppIndex, sources.count - 1))
        focusedKindIndex = max(0, min(focusedKindIndex, chips.count - 1))
        if focusZone == .apps, sources.isEmpty {
            focusZone = .cards
        }
        if focusZone == .kinds, chips.isEmpty {
            focusZone = .cards
        }
        let matches = filterHistory(history, filter: currentFilter(sources: sources))
        let visible = Array(matches.prefix(railLimit))
        if selectedID == nil || !visible.contains(where: { $0.id == selectedID }) {
            selectedID = visible.first?.id
        }
        present(
            presenter.present(
                items: visible,
                query: query,
                now: clock.now(),
                selectedID: selectedID,
                hiddenCount: matches.count - visible.count,
                filters: FilterContext(
                    sources: sources,
                    categories: categories,
                    activeSourceKey: activeSourceKey,
                    activeCategory: activeCategory,
                    focusedAppIndex: focusZone == .apps ? focusedAppIndex : nil,
                    focusedKindIndex: focusZone == .kinds ? focusedKindIndex : nil,
                    hasPinned: hasPinned,
                    pinnedOnly: pinnedOnly
                )
            )
        )
    }
}
