import AppKit
import SwiftUI

/// Space-bar preview: the selected card, live-updated as the selection
/// moves. The window decides the size — a short screen hands it less
/// room — and the content adapts to whatever it gets.
struct PreviewOverlayView: View {
    @ObservedObject var store: HistoryViewStateStore

    var body: some View {
        Group {
            if let card = store.state.selectedCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        if let icon = SourceAppStyle.resolve(bundleID: card.sourceBundleID).icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                                .accessibilityHidden(true)
                        }
                        Text(card.sourceLabel)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer()
                        Text("\(card.kindLabel) · \(card.timeLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    content(for: card)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(20)
            } else {
                Text(localized("Nothing selected"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous), cornerRadius: 24)
    }

    @ViewBuilder private func content(for card: CardViewState) -> some View {
        switch card.preview {
        case .text(let value):
            ScrollView {
                Text(value)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        case .code(let text, let tokens):
            ScrollView([.vertical, .horizontal]) {
                CodeTextView(text: text, tokens: tokens, lineLimit: nil)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        case .color(let code, let rgb):
            VStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(red: rgb.red, green: rgb.green, blue: rgb.blue))
                Text(code)
                    .font(.title3.monospaced())
            }
        case .link(let address):
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    LinkPreviewView(address: address, size: .large)
                    Text(address)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        case .image(let data):
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(localized("Image"))
            }
        case .files(let names, let overflow, let thumbnailPath):
            ScrollView {
                FilePreviewView(names: names, overflow: overflow, thumbnailPath: thumbnailPath, size: .large)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}
