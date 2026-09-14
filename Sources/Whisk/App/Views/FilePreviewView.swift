import AppKit
import SwiftUI

/// The files of a card: a QuickLook thumbnail of the first one (its type
/// icon until the thumbnail arrives), then the names. One view for the
/// card and the overlay; the size picks the proportions.
struct FilePreviewView: View {
    enum Size {
        case card
        case large
    }

    let names: [String]
    let overflow: Int
    let thumbnailPath: String?
    let size: Size
    @ObservedObject private var store = FileThumbnailStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: size == .card ? 7 : 10) {
            if let path = thumbnailPath {
                thumbnail(for: path)
            }
            ForEach(names, id: \.self) { name in
                switch size {
                case .card:
                    HStack(spacing: 6) {
                        Image(systemName: "doc")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text(name)
                            .font(.caption)
                            .lineLimit(1)
                    }
                case .large:
                    Label(name, systemImage: "doc")
                }
            }
            if overflow > 0 {
                Text(localized("+ \(overflow) more"))
                    .font(size == .card ? .caption2 : .body)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if let path = thumbnailPath {
                store.load(path)
            }
        }
    }

    @ViewBuilder private func thumbnail(for path: String) -> some View {
        let image = Image(nsImage: store.thumbnail(for: path) ?? NSWorkspace.shared.icon(forFile: path))
            .resizable()
            .aspectRatio(contentMode: .fit)
        switch size {
        case .card:
            image
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
        case .large:
            image
                .frame(maxHeight: 300)
                .accessibilityHidden(true)
        }
    }
}
