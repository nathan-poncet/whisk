import Foundation

/// Display-ready state for the history panel. Views render this verbatim;
/// all formatting decisions were made by the presenter.
public struct HistoryViewState: Equatable {
    public let cards: [CardViewState]
    public let countLabel: String
    public let query: String

    public init(cards: [CardViewState], countLabel: String, query: String) {
        self.cards = cards
        self.countLabel = countLabel
        self.query = query
    }

    public static let empty = HistoryViewState(cards: [], countLabel: "0 items", query: "")
}

/// One rendered clipboard entry.
public struct CardViewState: Equatable, Identifiable {
    public let id: UUID
    public let sourceLabel: String
    public let sourceBundleID: String?
    public let kindLabel: String
    public let timeLabel: String
    public let isPinned: Bool
    public let preview: CardPreview

    public init(
        id: UUID,
        sourceLabel: String,
        sourceBundleID: String?,
        kindLabel: String,
        timeLabel: String,
        isPinned: Bool,
        preview: CardPreview
    ) {
        self.id = id
        self.sourceLabel = sourceLabel
        self.sourceBundleID = sourceBundleID
        self.kindLabel = kindLabel
        self.timeLabel = timeLabel
        self.isPinned = isPinned
        self.preview = preview
    }
}

/// What a card shows, decided by the presenter. Image bytes stay opaque.
public enum CardPreview: Equatable {
    case text(String)
    case color(code: String, rgb: RGB)
    case link(String)
    case image(Data)
    case files(names: [String], overflow: Int)
}

/// Framework-free color triple in the 0...1 range.
public struct RGB: Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }
}
