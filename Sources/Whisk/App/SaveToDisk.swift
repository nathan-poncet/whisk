import AppKit

/// "Save As…" for a card: the bytes and a file name for what it holds,
/// then the system save panel. Files cards are not offered — they already
/// live on disk.
enum SaveToDisk {
    /// What would be written, and under which name; nil for a files card.
    static func proposal(for payload: DragPayload) -> (data: Data, name: String)? {
        switch payload {
        case .text(let value):
            return (Data(value.utf8), "Clipboard.txt")
        case .link(let url):
            return (Data(url.absoluteString.utf8), "Link.txt")
        case .image(let data):
            return (data, "Clipboard.png")
        case .files:
            return nil
        }
    }

    /// Runs the save panel and writes the card; the panel needs the app in
    /// front, which the non-activating history panel never is.
    static func present(_ payload: DragPayload) {
        guard let proposal = proposal(for: payload) else { return }
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = proposal.name
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try proposal.data.write(to: url, options: .atomic)
        } catch {
            ConsoleLogger().log("could not save the card — \(error)")
        }
    }
}
