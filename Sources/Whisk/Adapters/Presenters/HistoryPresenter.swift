import Foundation

/// What the controller knows about filtering, handed over for the chip bar.
/// The focused index is flat across the whole row: pinned chip first, then
/// the apps, then the categories.
struct FilterContext: Equatable {
    let sources: [SourceApp]
    let categories: [ContentCategory]
    let activeSourceKeys: Set<String>
    let activeCategories: Set<ContentCategory>
    let focusedChipIndex: Int?
    let hasPinned: Bool
    let pinnedOnly: Bool

    init(
        sources: [SourceApp],
        categories: [ContentCategory],
        activeSourceKeys: Set<String> = [],
        activeCategories: Set<ContentCategory> = [],
        focusedChipIndex: Int? = nil,
        hasPinned: Bool = false,
        pinnedOnly: Bool = false
    ) {
        self.sources = sources
        self.categories = categories
        self.activeSourceKeys = activeSourceKeys
        self.activeCategories = activeCategories
        self.focusedChipIndex = focusedChipIndex
        self.hasPinned = hasPinned
        self.pinnedOnly = pinnedOnly
    }

    static let empty = FilterContext(sources: [], categories: [])
}

/// Maps kernel entities to display-ready view state. Pure in behaviour —
/// time comes in as a value, never read from the system — with memoization
/// underneath: previews (regex tokenization, color parsing) and minute-
/// grained time labels are cached per immutable item, so a selection move
/// re-renders in microseconds instead of re-running regexes on 60 cards.
final class HistoryPresenter {
    private var previewCache: [UUID: CardPreview] = [:]
    private var timeCache: [UUID: (bucket: Int, label: String)] = [:]
    private let cacheLimit = 2048

    init() {}

    func present(
        items: [ClipboardItem],
        query: String,
        now: Date,
        selectedID: UUID? = nil,
        hiddenCount: Int = 0,
        stack: [UUID] = [],
        filters: FilterContext = .empty
    ) -> HistoryViewState {
        HistoryViewState(
            cards: items.map {
                card(
                    for: $0,
                    now: now,
                    isSelected: $0.id == selectedID,
                    stackPosition: stack.firstIndex(of: $0.id).map { $0 + 1 }
                )
            },
            countLabel: countLabel(items.count + hiddenCount),
            query: query,
            selectedID: selectedID,
            hiddenCount: hiddenCount,
            stackCount: stack.count,
            filters: filterBar(from: filters)
        )
    }

    private func card(
        for item: ClipboardItem, now: Date, isSelected: Bool, stackPosition: Int?
    ) -> CardViewState {
        let kind = Self.kindLabel(item.category)
        return CardViewState(
            id: item.id,
            sourceLabel: item.source?.name ?? item.source?.bundleID ?? kind.capitalized,
            sourceBundleID: item.source?.bundleID,
            kindLabel: kind,
            timeLabel: timeLabel(for: item, now: now),
            detailLabel: Self.detailLabel(for: item),
            isPinned: item.isPinned,
            isSelected: isSelected,
            stackPosition: stackPosition,
            preview: preview(for: item)
        )
    }

    /// Textual payloads carry their size in the footer, whether or not the
    /// preview had to fade out.
    private static func detailLabel(for item: ClipboardItem) -> String? {
        guard case .text(let value) = item.payload,
            item.category == .text || item.category == .code
        else { return nil }
        let count = value.count
        return count == 1 ? localized("1 character") : localized("\(count) characters")
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

    private func preview(for item: ClipboardItem) -> CardPreview {
        if let cached = previewCache[item.id] {
            return cached
        }
        let preview = computePreview(for: item)
        if previewCache.count >= cacheLimit {
            previewCache.removeAll(keepingCapacity: true)
        }
        previewCache[item.id] = preview
        return preview
    }

    private func computePreview(for item: ClipboardItem) -> CardPreview {
        switch item.payload {
        case .text(let value):
            switch item.category {
            case .color:
                if let swatch = colorSwatch(for: item.payload) {
                    return swatch
                }
                return .text(value)
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

    // Pinned leads its own group, then the apps, then the categories; the
    // controller mirrors this flat ordering for keyboard navigation.
    private func filterBar(from context: FilterContext) -> FilterBarViewState {
        var flatIndex = 0
        var pinned: [FilterChip] = []
        if context.hasPinned {
            pinned.append(
                FilterChip(
                    id: pinnedChipID,
                    label: localized("Pinned"),
                    sourceBundleID: nil,
                    isActive: context.pinnedOnly,
                    isFocused: flatIndex == context.focusedChipIndex
                )
            )
            flatIndex += 1
        }
        var apps: [FilterChip] = []
        for source in context.sources {
            apps.append(
                FilterChip(
                    id: source.filterKey,
                    label: source.name ?? source.bundleID ?? localized("Unknown"),
                    sourceBundleID: source.bundleID,
                    isActive: context.activeSourceKeys.contains(source.filterKey),
                    isFocused: flatIndex == context.focusedChipIndex
                )
            )
            flatIndex += 1
        }
        var kinds: [FilterChip] = []
        for category in context.categories {
            kinds.append(
                FilterChip(
                    id: category.rawValue,
                    label: Self.kindLabel(category).capitalized,
                    sourceBundleID: nil,
                    isActive: context.activeCategories.contains(category),
                    isFocused: flatIndex == context.focusedChipIndex
                )
            )
            flatIndex += 1
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
            timeCache.removeAll(keepingCapacity: true)
        }
        timeCache[item.id] = (bucket, label)
        return label
    }

    private func countLabel(_ count: Int) -> String {
        count == 1 ? localized("1 item") : localized("\(count) items")
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
