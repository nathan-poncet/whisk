import Foundation

/// Maps kernel entities to display-ready view state. Pure: time comes in as
/// a value, never read from the system.
struct HistoryPresenter {
    init() {}

    func present(items: [ClipboardItem], query: String, now: Date, selectedID: UUID? = nil) -> HistoryViewState {
        HistoryViewState(
            cards: items.map { card(for: $0, now: now, isSelected: $0.id == selectedID) },
            countLabel: countLabel(items.count),
            query: query,
            selectedID: selectedID
        )
    }

    private func card(for item: ClipboardItem, now: Date, isSelected: Bool) -> CardViewState {
        let kind = kindLabel(item.payload)
        return CardViewState(
            id: item.id,
            sourceLabel: item.source?.name ?? item.source?.bundleID ?? kind,
            sourceBundleID: item.source?.bundleID,
            kindLabel: kind.lowercased(),
            timeLabel: Self.relativeFormatter.localizedString(for: item.copiedAt, relativeTo: now),
            isPinned: item.isPinned,
            isSelected: isSelected,
            preview: preview(for: item.payload)
        )
    }

    private func preview(for payload: Payload) -> CardPreview {
        switch payload {
        case .text(let value):
            if let swatch = colorSwatch(in: value) {
                return swatch
            }
            return .text(value)
        case .link(let url):
            return .link(url.absoluteString)
        case .image(let data):
            return .image(data)
        case .fileReferences(let paths):
            let names = paths.map { ($0 as NSString).lastPathComponent }
            return .files(names: Array(names.prefix(4)), overflow: max(0, names.count - 4))
        }
    }

    private func colorSwatch(in text: String) -> CardPreview? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: "^#?[0-9a-fA-F]{6}$", options: .regularExpression) != nil else { return nil }
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard let value = UInt32(hex, radix: 16) else { return nil }
        return .color(
            code: "#" + hex.uppercased(),
            rgb: RGB(
                red: Double((value >> 16) & 0xFF) / 255,
                green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255
            )
        )
    }

    private func kindLabel(_ payload: Payload) -> String {
        switch payload {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        case .fileReferences: return "Files"
        }
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
