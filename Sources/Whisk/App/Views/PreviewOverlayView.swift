import AppKit
import SwiftUI

/// Space-bar preview: the selected card, full size, live-updated as the
/// selection moves.
struct PreviewOverlayView: View {
    @ObservedObject var store: HistoryViewStateStore

    private var card: CardViewState? {
        store.state.cards.first(where: \.isSelected)
    }

    var body: some View {
        Group {
            if let card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        if let icon = SourceAppStyle.resolve(bundleID: card.sourceBundleID).icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        Text(card.sourceLabel)
                            .font(.headline)
                        Spacer()
                        Text("\(card.kindLabel) · \(card.timeLabel)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    content(for: card)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .padding(20)
            } else {
                Text("Nothing selected")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 700, height: 480)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
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
            VStack(alignment: .leading, spacing: 10) {
                LinkCardPreviewLarge(address: address)
                Text(address)
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        case .image(let data):
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .files(let names, let overflow, let thumbnailPath):
            VStack(alignment: .leading, spacing: 10) {
                if let path = thumbnailPath {
                    Image(
                        nsImage: FileThumbnailStore.shared.thumbnail(for: path)
                            ?? NSWorkspace.shared.icon(forFile: path)
                    )
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .onAppear { FileThumbnailStore.shared.load(path) }
                }
                ForEach(names, id: \.self) { name in
                    Label(name, systemImage: "doc")
                }
                if overflow > 0 {
                    Text("+ \(overflow) more")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// The link preview at overlay size.
private struct LinkCardPreviewLarge: View {
    let address: String
    @ObservedObject private var store = LinkPreviewStore.shared

    var body: some View {
        Group {
            if let preview = store.preview(for: address), preview.hasContent {
                VStack(alignment: .leading, spacing: 10) {
                    if let image = preview.image {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    HStack(spacing: 8) {
                        if let icon = preview.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 18, height: 18)
                        }
                        Text(preview.title ?? address)
                            .font(.title3.weight(.medium))
                    }
                }
            } else {
                Image(systemName: "link")
                    .font(.title)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { store.load(address) }
    }
}
