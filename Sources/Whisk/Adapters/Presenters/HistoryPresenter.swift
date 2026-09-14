import Foundation

/// The pinned filter leads the chip row as its own group — it is neither
/// an application nor a content category.
let pinnedChipID = "pinned"

/// The three groups of the chip row, in display order.
enum ChipGroup: Equatable {
    case pinned
    case apps
    case kinds
}

/// One chip of the filter row. The row's order is decided in `row` alone:
/// the controller steers the keyboard along that list and the presenter
/// renders it, so an index can never land on a chip other than the one
/// drawn.
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

    var group: ChipGroup {
        switch self {
        case .pinned: .pinned
        case .app: .apps
        case .category: .kinds
        }
    }

    /// The pinned toggle first, then one chip per source application,
    /// then one per content category.
    static func row(hasPinned: Bool, sources: [SourceApp], categories: [ContentCategory]) -> [ChipEntry] {
        (hasPinned ? [ChipEntry.pinned] : []) + sources.map(ChipEntry.app) + categories.map(ChipEntry.category)
    }
}

/// What the controller knows about filtering, handed over for the chip
/// bar: the row as steered, which chips are active, and which one holds
/// the keyboard cursor.
struct FilterContext: Equatable {
    let chips: [ChipEntry]
    let activeSourceKeys: Set<String>
    let activeCategories: Set<ContentCategory>
    let pinnedOnly: Bool
    let focusedChipID: String?

    init(
        chips: [ChipEntry] = [],
        activeSourceKeys: Set<String> = [],
        activeCategories: Set<ContentCategory> = [],
        pinnedOnly: Bool = false,
        focusedChipID: String? = nil
    ) {
        self.chips = chips
        self.activeSourceKeys = activeSourceKeys
        self.activeCategories = activeCategories
        self.pinnedOnly = pinnedOnly
        self.focusedChipID = focusedChipID
    }

    static let empty = FilterContext()
}

/// Maps kernel entities to display-ready view state. Pure in behaviour —
/// time comes in as a value, never read from the system — with memoization
/// underneath: previews (regex tokenization, color parsing) and minute-
/// grained time labels are cached per immutable item, so a selection move
/// re-renders in microseconds instead of re-running regexes on 60 cards.
/// Past the limit a cache keeps only the items being presented, so what
/// is on screen never has to be recomputed and what was deleted is let go.
final class HistoryPresenter {
    private var previewCache: [UUID: CardPreview] = [:]
    private var timeCache: [UUID: (bucket: Int, label: String)] = [:]
    private var presentedIDs: Set<UUID> = []
    private let cacheLimit = 2048

    init() {}

    /// How many previews are held back, for the tests that watch the purge.
    var cachedPreviewCount: Int {
        previewCache.count
    }

    func present(
        items: [ClipboardItem],
        query: String,
        now: Date,
        selectedID: UUID? = nil,
        stack: [UUID] = [],
        filters: FilterContext = .empty
    ) -> HistoryViewState {
        presentedIDs = Set(items.map(\.id))
        let words = ParsedQuery(query).words
        return HistoryViewState(
            cards: items.map {
                card(
                    for: $0,
                    now: now,
                    isSelected: $0.id == selectedID,
                    stackPosition: stack.firstIndex(of: $0.id).map { $0 + 1 },
                    words: words
                )
            },
            countLabel: countLabel(items.count),
            query: query,
            selectedID: selectedID,
            stackCount: stack.count,
            filters: filterBar(from: filters),
            emptyMessage: items.isEmpty ? Self.emptyMessage(query: query, filters: filters) : nil
        )
    }

    /// An empty rail either invites the first copy or reports that the
    /// query and chips matched nothing.
    private static func emptyMessage(query: String, filters: FilterContext) -> String {
        let narrowed =
            !query.isEmpty || !filters.activeSourceKeys.isEmpty || !filters.activeCategories.isEmpty
            || filters.pinnedOnly
        return narrowed ? localized("No matches") : localized("Copy something to get started")
    }

    private func card(
        for item: ClipboardItem, now: Date, isSelected: Bool, stackPosition: Int?, words: [String]
    ) -> CardViewState {
        let kind = Self.kindLabel(item.category)
        let source = item.source?.name ?? item.source?.bundleID ?? kind.capitalized
        let time = timeLabel(for: item, now: now)
        let cardPreview = preview(for: item)
        return CardViewState(
            id: item.id,
            sourceLabel: source,
            sourceBundleID: item.source?.bundleID,
            kindLabel: kind,
            timeLabel: time,
            detailLabel: Self.detailLabel(for: item),
            isPinned: item.isPinned,
            isSelected: isSelected,
            stackPosition: stackPosition,
            accessibilityLabel: Self.accessibilityLabel(source: source, kind: kind, preview: cardPreview),
            accessibilityValue: Self.accessibilityValue(of: item, stackPosition: stackPosition, time: time),
            dragPayload: Self.dragPayload(of: item),
            matches: Self.matchSpans(of: words, in: item),
            preview: cardPreview
        )
    }

    /// Matching runs on the visible cards only and never on more than the
    /// preview can show; the cost is the filter's own, once more, per word.
    private static let matchScanLimit = 4000

    private static func matchSpans(of words: [String], in item: ClipboardItem) -> [MatchSpan] {
        guard !words.isEmpty, case .text(let value) = item.payload else { return [] }
        let scanned = String(value.prefix(matchScanLimit))
        var hits: Set<Int> = []
        for word in words {
            if let positions = FuzzyMatch.match(pattern: word, in: scanned)?.positions {
                hits.formUnion(positions)
            }
        }
        guard !hits.isEmpty else { return [] }
        // Character offsets to UTF-16 ones: one running offset per character.
        var utf16Offsets = [0]
        utf16Offsets.reserveCapacity(scanned.count + 1)
        for character in scanned {
            utf16Offsets.append(utf16Offsets[utf16Offsets.count - 1] + character.utf16.count)
        }
        var spans: [MatchSpan] = []
        var runStart: Int?
        var previous = -2
        for offset in hits.sorted() where offset + 1 < utf16Offsets.count {
            if offset != previous + 1 {
                if let start = runStart {
                    spans.append(
                        MatchSpan(start: utf16Offsets[start], length: utf16Offsets[previous + 1] - utf16Offsets[start]))
                }
                runStart = offset
            }
            previous = offset
        }
        if let start = runStart {
            spans.append(
                MatchSpan(start: utf16Offsets[start], length: utf16Offsets[previous + 1] - utf16Offsets[start]))
        }
        return spans
    }

    // A color travels as its code alone, the way the swatch shows it.
    private static func dragPayload(of item: ClipboardItem) -> DragPayload {
        switch item.payload {
        case .text(let value):
            return .text(item.category == .color ? value.trimmingCharacters(in: .whitespacesAndNewlines) : value)
        case .link(let url):
            return .link(url)
        case .image(let data):
            return .image(data)
        case .fileReferences(let paths):
            return .files(paths)
        }
    }

    private static func accessibilityLabel(source: String, kind: String, preview: CardPreview) -> String {
        var parts = [source, kind]
        if let summary = summary(of: preview) {
            parts.append(summary)
        }
        return parts.joined(separator: ", ")
    }

    private static let summaryLimit = 140

    /// One spoken line per card: whitespace collapsed, long text cut short.
    private static func summary(of preview: CardPreview) -> String? {
        switch preview {
        case .text(let value), .code(let value, _):
            let collapsed = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !collapsed.isEmpty else { return nil }
            return collapsed.count > summaryLimit ? String(collapsed.prefix(summaryLimit)) + "…" : collapsed
        case .color(let code, _):
            return code
        case .link(let address):
            return address
        case .image:
            return nil
        case .files(let names, let overflow, _):
            return (names + (overflow > 0 ? [localized("+ \(overflow) more")] : [])).joined(separator: ", ")
        }
    }

    private static func accessibilityValue(of item: ClipboardItem, stackPosition: Int?, time: String) -> String {
        var parts: [String] = []
        if item.isPinned {
            parts.append(localized("Pinned card"))
        }
        if let stackPosition {
            parts.append(localized("Paste stack position \(stackPosition)"))
        }
        parts.append(time)
        return parts.joined(separator: ", ")
    }

    /// Textual payloads carry their size in the footer, whether or not the
    /// preview had to fade out.
    private static func detailLabel(for item: ClipboardItem) -> String? {
        guard case .text(let value) = item.payload,
            item.category == .text || item.category == .code
        else { return nil }
        return localized("\(value.count) characters")
    }

    private static func kindLabel(_ category: ContentCategory) -> String {
        switch category {
        case .text: localized("text")
        case .code: localized("code")
        case .color: localized("color")
        case .link: localized("link")
        case .image: localized("image")
        case .files: localized("files")
        }
    }

    private static func chipIcon(_ category: ContentCategory) -> ChipIcon {
        switch category {
        case .text: .symbol("text.alignleft")
        // The code chip wears the Neovim mark when the bundle ships it.
        case .code: .resource("nvim", fallback: "chevron.left.forwardslash.chevron.right")
        case .color: .symbol("paintpalette")
        case .link: .symbol("link")
        case .image: .symbol("photo")
        case .files: .symbol("folder")
        }
    }

    private func preview(for item: ClipboardItem) -> CardPreview {
        if let cached = previewCache[item.id] {
            return cached
        }
        let preview = computePreview(for: item)
        if previewCache.count >= cacheLimit {
            previewCache = previewCache.filter { presentedIDs.contains($0.key) }
        }
        previewCache[item.id] = preview
        return preview
    }

    private func computePreview(for item: ClipboardItem) -> CardPreview {
        switch item.payload {
        case .text(let value):
            switch item.category {
            case .color:
                return colorSwatch(for: item.payload) ?? .text(value)
            case .code:
                return .code(text: value, tokens: CodeHighlighter.tokens(in: value))
            default:
                return .text(value)
            }
        case .link(let url):
            return .link(url.absoluteString)
        case .image(let data):
            return .image(data)
        case .fileReferences(let paths):
            let names = paths.map { ($0 as NSString).lastPathComponent }
            return .files(
                names: Array(names.prefix(4)),
                overflow: max(0, names.count - 4),
                thumbnailPath: paths.first
            )
        }
    }

    private func colorSwatch(for payload: Payload) -> CardPreview? {
        guard case .text(let value) = payload, let color = payload.parsedColor else { return nil }
        return .color(
            code: value.trimmingCharacters(in: .whitespacesAndNewlines),
            rgb: RGB(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        )
    }

    // The row arrives already ordered; each entry lands in its group.
    private func filterBar(from context: FilterContext) -> FilterBarViewState {
        var pinned: [FilterChip] = []
        var apps: [FilterChip] = []
        var kinds: [FilterChip] = []
        for entry in context.chips {
            let isFocused = entry.id == context.focusedChipID
            switch entry {
            case .pinned:
                pinned.append(
                    FilterChip(
                        id: entry.id,
                        label: localized("Pinned"),
                        sourceBundleID: nil,
                        icon: .symbol("pin.fill"),
                        accessibilityLabel: localized("Pinned items, filter"),
                        isActive: context.pinnedOnly,
                        isFocused: isFocused
                    )
                )
            case .app(let source):
                let label = source.name ?? source.bundleID ?? localized("Unknown")
                apps.append(
                    FilterChip(
                        id: entry.id,
                        label: label,
                        sourceBundleID: source.bundleID,
                        accessibilityLabel: localized("\(label), application filter"),
                        isActive: context.activeSourceKeys.contains(entry.id),
                        isFocused: isFocused
                    )
                )
            case .category(let category):
                let label = Self.kindLabel(category).capitalized
                kinds.append(
                    FilterChip(
                        id: entry.id,
                        label: label,
                        sourceBundleID: nil,
                        icon: Self.chipIcon(category),
                        accessibilityLabel: localized("\(label), kind filter"),
                        isActive: context.activeCategories.contains(category),
                        isFocused: isFocused
                    )
                )
            }
        }
        return FilterBarViewState(pinned: pinned, apps: apps, kinds: kinds)
    }

    /// Sub-minute labels would churn every second and force every card to
    /// re-render on each refresh, so the first minute reads as "now";
    /// beyond it the formatter only runs when the minute bucket moves.
    private func timeLabel(for item: ClipboardItem, now: Date) -> String {
        let age = now.timeIntervalSince(item.copiedAt)
        guard age >= 60 else { return localized("now") }
        let bucket = Int(age / 60)
        if let cached = timeCache[item.id], cached.bucket == bucket {
            return cached.label
        }
        let label = Self.relativeFormatter.localizedString(for: item.copiedAt, relativeTo: now)
        if timeCache.count >= cacheLimit {
            timeCache = timeCache.filter { presentedIDs.contains($0.key) }
        }
        timeCache[item.id] = (bucket, label)
        return label
    }

    private func countLabel(_ count: Int) -> String {
        localized("\(count) items")
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
