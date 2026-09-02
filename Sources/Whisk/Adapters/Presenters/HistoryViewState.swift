import Foundation

/// Display-ready state for the history panel. Views render this verbatim;
/// all formatting decisions were made by the presenter.
struct HistoryViewState: Equatable {
    let cards: [CardViewState]
    let countLabel: String
    let query: String
    let selectedID: UUID?
    let stackCount: Int
    let filters: FilterBarViewState

    init(
        cards: [CardViewState],
        countLabel: String,
        query: String,
        selectedID: UUID?,
        stackCount: Int = 0,
        filters: FilterBarViewState
    ) {
        self.cards = cards
        self.countLabel = countLabel
        self.query = query
        self.selectedID = selectedID
        self.stackCount = stackCount
        self.filters = filters
    }

    static let empty = HistoryViewState(
        cards: [],
        countLabel: "0 items",
        query: "",
        selectedID: nil,
        filters: .empty
    )
}

/// The chip bar, three groups in display order: the pinned toggle, one
/// chip per source application, one per content category — all adapted to
/// what the current selection can still match.
struct FilterBarViewState: Equatable {
    let pinned: [FilterChip]
    let apps: [FilterChip]
    let kinds: [FilterChip]

    init(pinned: [FilterChip] = [], apps: [FilterChip], kinds: [FilterChip]) {
        self.pinned = pinned
        self.apps = apps
        self.kinds = kinds
    }

    var isEmpty: Bool {
        pinned.isEmpty && apps.isEmpty && kinds.isEmpty
    }

    var hasActiveChip: Bool {
        (pinned + apps + kinds).contains(where: \.isActive)
    }

    var focusedChipID: String? {
        (pinned + apps + kinds).first(where: \.isFocused)?.id
    }

    static let empty = FilterBarViewState(apps: [], kinds: [])
}

struct FilterChip: Equatable, Identifiable {
    let id: String
    let label: String
    let sourceBundleID: String?
    let isActive: Bool
    let isFocused: Bool

    init(id: String, label: String, sourceBundleID: String?, isActive: Bool, isFocused: Bool) {
        self.id = id
        self.label = label
        self.sourceBundleID = sourceBundleID
        self.isActive = isActive
        self.isFocused = isFocused
    }
}

/// One rendered clipboard entry.
struct CardViewState: Equatable, Identifiable {
    let id: UUID
    let sourceLabel: String
    let sourceBundleID: String?
    let kindLabel: String
    let timeLabel: String
    /// Extra footer fact, e.g. the character count of textual payloads.
    let detailLabel: String?
    let isPinned: Bool
    let isSelected: Bool
    /// 1-based rank in the paste stack, nil when the card isn't queued.
    let stackPosition: Int?
    let preview: CardPreview

    init(
        id: UUID,
        sourceLabel: String,
        sourceBundleID: String?,
        kindLabel: String,
        timeLabel: String,
        detailLabel: String? = nil,
        isPinned: Bool,
        isSelected: Bool,
        stackPosition: Int? = nil,
        preview: CardPreview
    ) {
        self.id = id
        self.sourceLabel = sourceLabel
        self.sourceBundleID = sourceBundleID
        self.kindLabel = kindLabel
        self.timeLabel = timeLabel
        self.detailLabel = detailLabel
        self.isPinned = isPinned
        self.isSelected = isSelected
        self.stackPosition = stackPosition
        self.preview = preview
    }
}

/// What a card shows, decided by the presenter. Image bytes stay opaque.
enum CardPreview: Equatable {
    case text(String)
    case code(text: String, tokens: [CodeToken])
    case color(code: String, rgb: RGB)
    case link(String)
    case image(Data)
    case files(names: [String], overflow: Int, thumbnailPath: String?)
}

/// Framework-free color components in the 0...1 range.
struct RGB: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
}
