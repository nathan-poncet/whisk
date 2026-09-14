import Foundation

/// One step of keyboard navigation through the visible cards.
enum SelectionMove {
    case previous
    case next
}

/// The two ends a jump can land on — the whole rail or the whole chip row.
enum SelectionEdge {
    case start
    case end
}

/// Which region of the panel the keyboard is steering. The chip row is a
/// single zone — pinned, applications and categories are groups inside it,
/// crossed with plain arrows.
enum PanelZone {
    case chips
    case cards
}

/// Which way the rail and the chip row flow. Left and right arrows are
/// visual: they mirror in a right-to-left layout.
enum LayoutDirection {
    case leftToRight
    case rightToLeft
}

/// A key-arrow press, routed by the controller to a zone change (up/down)
/// or a move within the focused zone (left/right).
enum ArrowDirection {
    case up
    case down
    case left
    case right
}

/// Translates UI and OS events into use case invocations and hands each
/// result to the presenter. Owns the current history, search query and
/// keyboard selection; generic over its gateways, like the use cases it
/// drives. A storage failure is logged and the in-memory state keeps
/// working.
final class ClipboardController<Board: Pasteboard, Time: Clock, Store: HistoryStore, Log: Logger> {
    private var history: History
    private var query = ""
    private var activeSourceKeys: Set<String> = []
    private var activeCategories: Set<ContentCategory> = []
    private var pinnedOnly = false
    private var retention: RetentionPolicy
    /// When the oldest unpinned item crosses the age limit. Any mutation
    /// re-arms it for the next tick: an unpin or a capture can change
    /// which item expires first.
    private var nextExpiry: Date = .distantPast
    private var isPaused = false
    private var excludedBundleIDs: Set<String> = []
    private var pasteStack: [UUID] = []
    private var selectedID: UUID?
    private var focusZone: PanelZone = .cards
    /// Focus anchors to the chip's identity: toggling a filter reshapes
    /// the row, and an index would land the cursor on a different chip.
    private var focusedChipID: String?
    private var focusedChipIndex = 0
    private var layoutDirection: LayoutDirection = .leftToRight
    /// The chip row and the rail as of the last refresh. Every input they
    /// derive from changes only through methods that end in refresh, so a
    /// key press reads them instead of filtering the history again.
    private var cachedChips: [ChipEntry] = []
    private var cachedVisible: [ClipboardItem] = []

    private let capture: CaptureClipboardChange<Board, Time, Store>
    private let selectItem: SelectItem<Board, Time, Store>
    private let togglePinItem: TogglePin<Store>
    private let deleteItem: DeleteItem<Store>
    private let deleteMatching: DeleteMatching<Store>
    private let editItem: EditItem<Store>
    private let clearUnpinned: ClearHistory<Store>
    private let enforceRetention: EnforceRetention<Store>
    private let filterHistory = FilterHistory()
    private let presenter: HistoryPresenter
    private let clock: Time
    private let pasteboard: Board
    private let logger: Log
    private let present: (HistoryViewState) -> Void

    /// The retention policy shapes the history from the first load: a
    /// history rebuilt at the default capacity would evict what a roomier
    /// setting had kept, and the next save would make that permanent.
    init(
        pasteboard: Board,
        store: Store,
        clock: Time,
        retention: RetentionPolicy = .standard,
        presenter: HistoryPresenter = HistoryPresenter(),
        logger: Log,
        present: @escaping (HistoryViewState) -> Void
    ) {
        self.clock = clock
        self.presenter = presenter
        self.pasteboard = pasteboard
        self.logger = logger
        self.present = present
        self.retention = retention
        capture = CaptureClipboardChange(pasteboard: pasteboard, clock: clock, store: store)
        selectItem = SelectItem(pasteboard: pasteboard, clock: clock, store: store)
        togglePinItem = TogglePin(store: store)
        deleteItem = DeleteItem(store: store)
        deleteMatching = DeleteMatching(store: store)
        editItem = EditItem(store: store)
        clearUnpinned = ClearHistory(store: store)
        enforceRetention = EnforceRetention(store: store)
        do {
            history = try LoadHistory(store: store, capacity: retention.capacity)()
        } catch {
            logger.log("could not load history — \(error)")
            history = History(capacity: retention.capacity)
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
        guard retention.maxAge != nil, clock.now() >= nextExpiry else { return }
        enforceRetentionNow()
    }

    /// Suspends or resumes capture; everything else keeps working.
    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    /// The arrows follow the direction the interface reads in.
    func setLayoutDirection(_ direction: LayoutDirection) {
        layoutDirection = direction
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
            logger.log("storage failure — \(error)")
        }
        nextExpiry = earliestExpiry()
        guard history != previous else { return }
        refresh()
    }

    // The poll skips retention until then rather than re-walking the
    // whole history four times a second.
    private func earliestExpiry() -> Date {
        guard let maxAge = retention.maxAge,
            let oldest = history.items.filter({ !$0.isPinned }).map(\.copiedAt).min()
        else { return .distantFuture }
        return oldest.addingTimeInterval(maxAge)
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

    /// Puts a rewritten copy of the card's text on the pasteboard. False
    /// when the card holds no text the transform can read — nothing is
    /// written then, so the caller keeps the panel open.
    @discardableResult
    func select(_ id: UUID, transform: TextTransform) -> Bool {
        guard let item = history.items.first(where: { $0.id == id }),
            let text = item.payload.transformableText,
            let rewritten = transform.apply(to: text)
        else { return false }
        mutate { try selectItem(id, in: $0, writing: .text(rewritten)) }
        return true
    }

    /// Moves the keyboard selection through the visible cards, clamped at
    /// both ends. refresh keeps the selection on a visible card, so a miss
    /// can only mean an empty rail.
    func moveSelection(_ step: SelectionMove) {
        let items = visibleItems
        guard let current = selectedID, let index = items.firstIndex(where: { $0.id == current }) else { return }
        let destination = step == .next ? min(index + 1, items.count - 1) : max(index - 1, 0)
        selectedID = items[destination].id
        refresh()
    }

    /// Jumps the keyboard focus to either end of whatever zone holds it.
    func jumpSelection(to edge: SelectionEdge) {
        switch focusZone {
        case .cards:
            let items = visibleItems
            guard !items.isEmpty else { return }
            selectedID = (edge == .start ? items.first : items.last)?.id
        case .chips:
            let chips = chipEntries
            guard !chips.isEmpty else { return }
            focusedChipID = (edge == .start ? chips.first : chips.last)?.id
        }
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
            let forward = (direction == .right) == (layoutDirection == .leftToRight)
            navigateHorizontally(forward ? 1 : -1)
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
        toggleStack(id)
    }

    /// Queues a card, or removes it when already queued.
    func toggleStack(_ id: UUID) {
        guard history.items.contains(where: { $0.id == id }) else { return }
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
        // Deleting the selection keeps the cursor in place: the neighbor
        // below slides into the hole and inherits the selection (the one
        // above when the last card goes).
        if id == selectedID {
            let items = visibleItems
            if let index = items.firstIndex(where: { $0.id == id }) {
                let successor =
                    index + 1 < items.count
                    ? items[index + 1]
                    : (index > 0 ? items[index - 1] : nil)
                selectedID = successor?.id
            }
        }
        mutate { try deleteItem(id, in: $0) }
    }

    func deleteSelected() {
        guard let id = selectedID else { return }
        delete(id)
    }

    func clear() {
        mutate { try clearUnpinned($0) }
    }

    /// Replaces a card's text with what the user rewrote.
    func edit(_ id: UUID, text: String) {
        mutate { try editItem(id, text: text, in: $0) }
    }

    /// Removes every unpinned card copied from one application.
    func deleteAll(fromSource key: String) {
        mutate { try deleteMatching({ $0.source?.filterKey == key }, in: $0) }
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

    /// What the chip row derives from the history under the current
    /// filters, computed once per refresh.
    private struct Facets {
        let sources: [SourceApp]
        let categories: [ContentCategory]
        let activeCategories: Set<ContentCategory>
        let hasPinned: Bool
    }

    // Each facet narrows what the OTHER displays — selecting image hides
    // the apps that never produced an image, selecting Spotify hides the
    // categories Spotify never yielded — but an ACTIVE chip is never
    // hidden, so a selection can never be dropped by ricochet. Impossible
    // combinations are unreachable because their chips vanish before they
    // can be clicked. Active categories only fall when a history mutation
    // (deletion, eviction) makes them impossible.
    private func computeFacets() -> Facets {
        let active = distinctSources(of: history.items).filter { activeSourceKeys.contains($0.filterKey) }
        let underApps = filterHistory(history, filter: HistoryFilter(sources: active, pinnedOnly: pinnedOnly))
        let reachable = Set(underApps.map(\.category))
        let activeCategories = self.activeCategories.intersection(reachable)
        let underCategories = filterHistory(
            history, filter: HistoryFilter(categories: activeCategories, pinnedOnly: pinnedOnly))
        let scopedSources = distinctSources(of: underCategories)
        let strayActives = active.filter { stray in !scopedSources.contains { $0.filterKey == stray.filterKey } }
        let hasPinned = filterHistory(
            history, filter: HistoryFilter(sources: active, categories: activeCategories)
        ).contains(where: \.isPinned)
        return Facets(
            sources: scopedSources + strayActives,
            categories: ContentCategory.allCases.filter(reachable.contains),
            activeCategories: activeCategories,
            hasPinned: hasPinned
        )
    }

    /// The row the keyboard steers — the same list the presenter renders.
    private var chipEntries: [ChipEntry] {
        cachedChips
    }

    /// First flat index of each chip group actually present, for ⌃⇥.
    private var chipGroupStarts: [Int] {
        var starts: [Int] = []
        var previous: ChipGroup?
        for (index, chip) in chipEntries.enumerated() where chip.group != previous {
            starts.append(index)
            previous = chip.group
        }
        return starts
    }

    private func currentFilter() -> HistoryFilter {
        HistoryFilter(
            query: query,
            sources: distinctSources(of: history.items).filter { activeSourceKeys.contains($0.filterKey) },
            categories: activeCategories,
            pinnedOnly: pinnedOnly
        )
    }

    private var visibleItems: [ClipboardItem] {
        cachedVisible
    }

    private func mutate(_ transform: (History) throws -> History) {
        let previous = history
        do {
            history = try transform(history)
        } catch {
            logger.log("storage failure — \(error)")
        }
        guard history != previous else { return }
        nextExpiry = .distantPast
        refresh()
    }

    private func refresh() {
        // App keys survive as long as the app exists in the history at all.
        activeSourceKeys = activeSourceKeys.filter { key in
            history.items.contains { $0.source?.filterKey == key }
        }
        var facets = computeFacets()
        if pinnedOnly, !facets.hasPinned {
            pinnedOnly = false
            facets = computeFacets()
        }
        activeCategories = facets.activeCategories
        cachedChips = ChipEntry.row(hasPinned: facets.hasPinned, sources: facets.sources, categories: facets.categories)
        focusedChipIndex = resolvedChipIndex(in: cachedChips)
        focusedChipID = cachedChips.indices.contains(focusedChipIndex) ? cachedChips[focusedChipIndex].id : nil
        if focusZone == .chips, cachedChips.isEmpty {
            focusZone = .cards
        }
        cachedVisible = filterHistory(history, filter: currentFilter())
        if selectedID == nil || !cachedVisible.contains(where: { $0.id == selectedID }) {
            selectedID = cachedVisible.first?.id
        }
        pasteStack.removeAll { id in !history.items.contains(where: { $0.id == id }) }
        present(
            presenter.present(
                items: cachedVisible,
                query: query,
                now: clock.now(),
                // One cursor at a time: while the chip row holds it, no
                // card wears the ring — the selection itself survives for
                // the way back down.
                selectedID: focusZone == .cards ? selectedID : nil,
                stack: pasteStack,
                filters: FilterContext(
                    chips: cachedChips,
                    activeSourceKeys: activeSourceKeys,
                    activeCategories: activeCategories,
                    pinnedOnly: pinnedOnly,
                    focusedChipID: focusZone == .chips ? focusedChipID : nil
                )
            )
        )
    }
}
