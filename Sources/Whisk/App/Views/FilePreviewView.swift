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

    /// One way to lay the files out: the thumbnail or not, the first
    /// `shown` names, and how many the "+ N more" line stands for.
    struct Fit: Hashable {
        let thumbnail: Bool
        let shown: Int
        let hidden: Int
    }

    let names: [String]
    let overflow: Int
    let thumbnailPath: String?
    let size: Size
    @ObservedObject private var store = FileThumbnailStore.shared

    /// Every layout a card may fall back to, fullest first: all the names
    /// under the thumbnail, then fewer, then the same run without the
    /// thumbnail — the names are what identifies the copy. The last one
    /// is the most compact, so something always fits.
    static func fits(names: Int, overflow: Int, thumbnail: Bool) -> [Fit] {
        let runs = names > 0 ? Array(stride(from: names, through: 1, by: -1)) : [0]
        let withThumbnail = thumbnail ? [true, false] : [false]
        return withThumbnail.flatMap { thumbnail in
            runs.map { shown in
                Fit(thumbnail: thumbnail, shown: shown, hidden: overflow + names - shown)
            }
        }
    }

    var body: some View {
        Group {
            switch size {
            case .card:
                // A card is a fixed square; four names under a thumbnail
                // overflow the small one, so the card takes the fullest
                // layout its height holds.
                ViewThatFits(in: .vertical) {
                    ForEach(
                        Self.fits(names: names.count, overflow: overflow, thumbnail: thumbnailPath != nil),
                        id: \.self
                    ) { fit in
                        list(fit)
                    }
                }
            case .large:
                list(Fit(thumbnail: thumbnailPath != nil, shown: names.count, hidden: overflow))
            }
        }
        .onAppear {
            if let path = thumbnailPath {
                store.load(path)
            }
        }
    }

    private func list(_ fit: Fit) -> some View {
        VStack(alignment: .leading, spacing: size == .card ? 7 : 10) {
            if fit.thumbnail, let path = thumbnailPath {
                thumbnail(for: path)
            }
            ForEach(names.prefix(fit.shown), id: \.self) { name in
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
            if fit.hidden > 0 {
                Text(localized("+ \(fit.hidden) more"))
                    .font(size == .card ? .caption2 : .body)
                    .foregroundStyle(.secondary)
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
