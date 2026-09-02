import Foundation

/// One step of keyboard navigation through the visible cards.
enum SelectionMove {
    case previous
    case next
}

/// Which region of the panel the keyboard is steering. The chip row is a
/// single zone — pinned, applications and categories are groups inside it,
/// crossed with plain arrows.
enum PanelZone {
    case chips
    case cards
}

/// One chip of the filter row, in display order: the pinned toggle first,
/// then one chip per source application, then one per content category.
enum ChipEntry: Equatable {
    case pinned
    case app(SourceApp)
    case category(ContentCategory)

    var id: String {
        switch self {
        case .pinned: pinnedChipID
        case .app(let source): source.filterKey
        case .category(let category): category.rawValue
        }
    }
}

/// A key-arrow press, routed by the controller to a zone change (up/down)
/// or a move within the focused zone (left/right).
enum ArrowDirection {
    case up
    case down
    case left
    case right
}

/// The pinned filter leads the chip row as its own group — it is neither
/// an application nor a content category; controller navigation and
/// presenter rendering share this id.
let pinnedChipID = "pinned"

/// Translates UI and OS events into use case invocations and hands each
/// result to the presenter. Owns the current history, search query and
/// keyboard selection; generic over its gateways, like the use cases it
/// drives. A storage failure is logged and the in-memory state keeps
/// working.
final class ClipboardController<Board: Pasteboard, Time: Clock, Store: HistoryStore> {
    private var history: History
    private var query = ""
    private var activeSourceKeys: Set<String> = []
    private var activeCategories: Set<ContentCategory> = []
    private var pinnedOnly = false
    private var retention = RetentionPolicy.standard
    private var isPaused = false
    private var excludedBundleIDs: Set<String> = []
    private var pasteStack: [UUID] = []
    private var selectedID: UUID?
    private var focusZone: PanelZone = .cards
    /// Focus anchors to the chip's identity: toggling a filter reshapes
    /// the row, and an index would land the cursor on a different chip.
    private var focusedChipID: String?
    private var focusedChipIndex = 0

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

    /// Adds a source application to the filter, or removes it when already
    /// selected — several may be active at once (OR).
    func toggleSourceFilter(_ key: String) {
        if activeSourceKeys.remove(key) == nil {
            activeSourceKeys.insert(key)
        }
        selectedID = nil
        refresh()
    }

    /// Adds a content category to the filter, or removes it when already
    /// selected — or toggles the pinned filter when given the pinned chip.
    func toggleCategoryFilter(_ rawCategory: String) {
        if rawCategory == pinnedChipID {
            pinnedOnly.toggle()
            selectedID = nil
            refresh()
            return
        }
        guard let category = ContentCategory(rawValue: rawCategory) else { return }
        if activeCategories.remove(category) == nil {
            activeCategories.insert(category)
        }
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
        focusChip(id: key)
    }

    /// Moves the keyboard focus onto a specific kind chip (or the pinned
    /// chip).
    func focusCategoryChip(_ chipID: String) {
        focusChip(id: chipID)
    }

    private func focusChip(id: String) {
        guard chipEntries.contains(where: { $0.id == id }) else { return }
        guard focusZone != .chips || focusedChipID != id else { return }
        focusZone = .chips
        focusedChipID = id
        refresh()
    }

    /// The focused chip's current position, resolved by identity first and
    /// by the last known index when the chip vanished.
    private func resolvedChipIndex(in chips: [ChipEntry]) -> Int {
        if let id = focusedChipID, let index = chips.firstIndex(where: { $0.id == id }) {
            return index
        }
        return max(0, min(focusedChipIndex, chips.count - 1))
    }

    /// Up and down move between the chip row and the rail; left and right
    /// move within whichever zone holds the focus.
    func navigate(_ direction: ArrowDirection) {
        switch direction {
        case .left, .right:
            navigateHorizontally(direction == .right ? 1 : -1)
        case .up:
            if focusZone == .cards, !chipEntries.isEmpty {
                focusZone = .chips
            }
            refresh()
        case .down:
            focusZone = .cards
            refresh()
        }
    }

    /// Jumps to the start of the next chip group (pinned → apps →
    /// categories, cyclically) — the fast lane next to arrowing across
    /// the separators.
    func switchChipGroup() {
        let chips = chipEntries
        let starts = chipGroupStarts
        guard !starts.isEmpty, !chips.isEmpty else { return }
        if focusZone != .chips {
            focusZone = .chips
            focusedChipID = chips[starts[0]].id
        } else {
            let index = resolvedChipIndex(in: chips)
            let current = starts.lastIndex { $0 <= index } ?? 0
            focusedChipID = chips[starts[(current + 1) % starts.count]].id
        }
        refresh()
    }

    // The chip groups share one visual row: arrowing simply walks the row,
    // crossing the separators.
    private func navigateHorizontally(_ step: Int) {
        switch focusZone {
        case .cards:
            moveSelection(step > 0 ? .next : .previous)
        case .chips:
            let chips = chipEntries
            guard !chips.isEmpty else { return }
            let destination = max(0, min(resolvedChipIndex(in: chips) + step, chips.count - 1))
            focusedChipID = chips[destination].id
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
        case .chips:
            let chips = chipEntries
            guard !chips.isEmpty else { return false }
            switch chips[resolvedChipIndex(in: chips)] {
            case .pinned:
                toggleCategoryFilter(pinnedChipID)
            case .app(let source):
                toggleSourceFilter(source.filterKey)
            case .category(let category):
                toggleCategoryFilter(category.rawValue)
            }
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

    /// Queues the highlighted card, or removes it when already queued; the
    /// global paste-next shortcut then pops the queue one item per press.
    func stackSelected() {
        guard let id = selectedID else { return }
        if let index = pasteStack.firstIndex(of: id) {
            pasteStack.remove(at: index)
        } else {
            pasteStack.append(id)
        }
        refresh()
    }

    /// Writes the next queued payload to the pasteboard. Deleted items are
    /// skipped; returns false once the queue is exhausted.
    @discardableResult
    func popStack() -> Bool {
        while !pasteStack.isEmpty {
            let id = pasteStack.removeFirst()
            if let item = history.items.first(where: { $0.id == id }) {
                pasteboard.write(item.payload, rtf: item.rtf)
                refresh()
                return true
            }
        }
        refresh()
        return false
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
        activeSourceKeys = []
        activeCategories = []
        pinnedOnly = false
        selectedID = nil
        focusZone = .cards
        focusedChipID = nil
        focusedChipIndex = 0
        refresh()
    }

    // One chip per application: deduplicated leniently (items recorded
    // before bundle ids existed carry a name only), preferring the variant
    // that has a bundle id so the chip gets an icon.
    private func distinctSources(of items: [ClipboardItem]) -> [SourceApp] {
        var chips: [SourceApp] = []
        for item in items {
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

    private var activeSources: [SourceApp] {
        distinctSources(of: history.items).filter { activeSourceKeys.contains($0.filterKey) }
    }

    // Each facet narrows what the OTHER displays — selecting image hides
    // the apps that never produced an image, selecting Spotify hides the
    // categories Spotify never yielded — but an ACTIVE chip is never
    // hidden, so a selection can never be dropped by ricochet. Impossible
    // combinations are unreachable because their chips vanish before they
    // can be clicked.
    private var availableSources: [SourceApp] {
        let scoped = distinctSources(
            of: filterHistory(
                history,
                filter: HistoryFilter(categories: activeCategories, pinnedOnly: pinnedOnly)
            )
        )
        let strayActives = activeSources.filter { active in
            !scoped.contains { $0.filterKey == active.filterKey }
        }
        return scoped + strayActives
    }

    private var availableCategories: [ContentCategory] {
        let matches = filterHistory(
            history,
            filter: HistoryFilter(sources: activeSources, pinnedOnly: pinnedOnly)
        )
        let present = Set(matches.map(\.category)).union(activeCategories)
        return ContentCategory.allCases.filter(present.contains)
    }

    private var hasPinnedInScope: Bool {
        filterHistory(
            history,
            filter: HistoryFilter(sources: activeSources, categories: activeCategories)
        ).contains(where: \.isPinned)
    }

    // Mirrors the presenter's chip ordering — pinned, then apps, then
    // categories — so keyboard indices land on what is drawn.
    private var chipEntries: [ChipEntry] {
        (hasPinnedInScope ? [ChipEntry.pinned] : [])
            + availableSources.map { ChipEntry.app($0) }
            + availableCategories.map { ChipEntry.category($0) }
    }

    /// First flat index of each chip group actually present, for ⌃⇥.
    private var chipGroupStarts: [Int] {
        var starts: [Int] = []
        var offset = 0
        if hasPinnedInScope {
            starts.append(0)
            offset += 1
        }
        let sources = availableSources
        if !sources.isEmpty {
            starts.append(offset)
            offset += sources.count
        }
        if !availableCategories.isEmpty {
            starts.append(offset)
        }
        return starts
    }

    private func currentFilter() -> HistoryFilter {
        HistoryFilter(
            query: query,
            sources: activeSources,
            categories: activeCategories,
            pinnedOnly: pinnedOnly
        )
    }

    private var visibleItems: [ClipboardItem] {
        filterHistory(history, filter: currentFilter())
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
        // Reconcile the facets: app keys survive as long as the app exists
        // in the history at all; active categories only fall when a history
        // mutation (deletion, eviction) makes them impossible — the UI
        // itself cannot build an impossible combination.
        activeSourceKeys = activeSourceKeys.filter { key in
            history.items.contains { $0.source?.filterKey == key }
        }
        let sources = availableSources
        let scopedCategories = Set(
            filterHistory(
                history,
                filter: HistoryFilter(sources: activeSources, pinnedOnly: pinnedOnly)
            ).map(\.category)
        )
        activeCategories = activeCategories.intersection(scopedCategories)
        let categories = availableCategories
        let pinnedInScope = hasPinnedInScope
        if pinnedOnly, !pinnedInScope {
            pinnedOnly = false
        }
        let chips = chipEntries
        focusedChipIndex = resolvedChipIndex(in: chips)
        focusedChipID = chips.indices.contains(focusedChipIndex) ? chips[focusedChipIndex].id : nil
        if focusZone == .chips, chips.isEmpty {
            focusZone = .cards
        }
        let visible = filterHistory(history, filter: currentFilter())
        if selectedID == nil || !visible.contains(where: { $0.id == selectedID }) {
            selectedID = visible.first?.id
        }
        pasteStack.removeAll { id in !history.items.contains(where: { $0.id == id }) }
        present(
            presenter.present(
                items: visible,
                query: query,
                now: clock.now(),
                selectedID: selectedID,
                stack: pasteStack,
                filters: FilterContext(
                    sources: sources,
                    categories: categories,
                    activeSourceKeys: activeSourceKeys,
                    activeCategories: activeCategories,
                    focusedChipIndex: focusZone == .chips ? focusedChipIndex : nil,
                    hasPinned: pinnedInScope,
                    pinnedOnly: pinnedOnly
                )
            )
        )
    }
}
