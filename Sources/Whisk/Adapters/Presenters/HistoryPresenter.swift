import Foundation

/// What the controller knows about filtering, handed over for the chip bar.
struct FilterContext: Equatable {
    let sources: [SourceApp]
    let categories: [ContentCategory]
    let activeSourceKey: String?
    let activeCategory: ContentCategory?
    let focusedAppIndex: Int?
    let focusedKindIndex: Int?
    let hasPinned: Bool
    let pinnedOnly: Bool

    init(
        sources: [SourceApp],
        categories: [ContentCategory],
        activeSourceKey: String?,
        activeCategory: ContentCategory?,
        focusedAppIndex: Int? = nil,
        focusedKindIndex: Int? = nil,
        hasPinned: Bool = false,
        pinnedOnly: Bool = false
    ) {
        self.sources = sources
        self.categories = categories
        self.activeSourceKey = activeSourceKey
        self.activeCategory = activeCategory
        self.focusedAppIndex = focusedAppIndex
        self.focusedKindIndex = focusedKindIndex
        self.hasPinned = hasPinned
        self.pinnedOnly = pinnedOnly
    }

    static let empty = FilterContext(sources: [], categories: [], activeSourceKey: nil, activeCategory: nil)
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
        stackCount: Int = 0,
        filters: FilterContext = .empty
    ) -> HistoryViewState {
        HistoryViewState(
            cards: items.map { card(for: $0, now: now, isSelected: $0.id == selectedID) },
            countLabel: countLabel(items.count + hiddenCount),
            query: query,
            selectedID: selectedID,
            hiddenCount: hiddenCount,
            stackCount: stackCount,
            filters: filterBar(from: filters)
        )
    }

    private func card(for item: ClipboardItem, now: Date, isSelected: Bool) -> CardViewState {
        CardViewState(
            id: item.id,
            sourceLabel: item.source?.name ?? item.source?.bundleID ?? item.category.rawValue.capitalized,
            sourceBundleID: item.source?.bundleID,
            kindLabel: item.category.rawValue,
            timeLabel: timeLabel(for: item, now: now),
            isPinned: item.isPinned,
            isSelected: isSelected,
            preview: preview(for: item)
        )
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
        guard let code = payload.hexColorCode,
            let value = UInt32(code.dropFirst(), radix: 16)
        else { return nil }
        return .color(
            code: code,
            rgb: RGB(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255
            )
        )
    }

    private func filterBar(from context: FilterContext) -> FilterBarViewState {
        FilterBarViewState(
            apps: context.sources.enumerated().map { index, source in
                FilterChip(
                    id: source.filterKey,
                    label: source.name ?? source.bundleID ?? "Unknown",
                    sourceBundleID: source.bundleID,
                    isActive: source.filterKey == context.activeSourceKey,
                    isFocused: index == context.focusedAppIndex
                )
            },
            kinds: kindChips(from: context)
        )
    }

    // Pinned first, then the categories — the controller mirrors this
    // ordering for keyboard navigation.
    private func kindChips(from context: FilterContext) -> [FilterChip] {
        var chips: [FilterChip] = []
        if context.hasPinned {
            chips.append(
                FilterChip(
                    id: pinnedChipID,
                    label: "Pinned",
                    sourceBundleID: nil,
                    isActive: context.pinnedOnly,
                    isFocused: chips.count == context.focusedKindIndex
                )
            )
        }
        for category in context.categories {
            chips.append(
                FilterChip(
                    id: category.rawValue,
                    label: category.rawValue.capitalized,
                    sourceBundleID: nil,
                    isActive: category == context.activeCategory,
                    isFocused: chips.count == context.focusedKindIndex
                )
            )
        }
        return chips
    }

    /// Sub-minute labels would churn every second and force every card to
    /// re-render on each refresh, so the first minute reads as "now";
    /// beyond it the formatter only runs when the minute bucket moves.
    private func timeLabel(for item: ClipboardItem, now: Date) -> String {
        let age = now.timeIntervalSince(item.copiedAt)
        guard age >= 60 else { return "now" }
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
        count == 1 ? "1 item" : "\(count) items"
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}
