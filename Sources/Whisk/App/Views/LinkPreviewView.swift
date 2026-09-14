import AppKit
import SwiftUI

/// A link's fetched page metadata — title, favicon, lead image — when
/// available, the bare address until then or when the fetch failed. One
/// view for the card and the overlay; the size picks the proportions.
struct LinkPreviewView: View {
    enum Size {
        case card
        case large
    }

    let address: String
    let size: Size
    @ObservedObject private var store = LinkPreviewStore.shared

    var body: some View {
        Group {
            if let preview = store.preview(for: address), preview.hasContent {
                loaded(preview)
            } else {
                fallback
            }
        }
        .onAppear {
            store.load(address)
        }
    }

    private func loaded(_ preview: LinkPreview) -> some View {
        VStack(alignment: .leading, spacing: size == .card ? 7 : 10) {
            if let image = preview.image {
                heroImage(image)
            }
            HStack(alignment: .top, spacing: size == .card ? 6 : 8) {
                if let icon = preview.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: iconSide, height: iconSide)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        .accessibilityHidden(true)
                }
                Text(preview.title ?? address)
                    .font(titleFont)
                    .lineLimit(size == .card ? (preview.image == nil ? 4 : 2) : nil)
            }
            if size == .card, preview.title != nil, let host = preview.host {
                Text(host)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func heroImage(_ image: NSImage) -> some View {
        switch size {
        case .card:
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
        case .large:
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityHidden(true)
        }
    }

    private var iconSide: CGFloat {
        size == .card ? 15 : 18
    }

    private var titleFont: Font {
        size == .card ? .callout.weight(.medium) : .title3.weight(.medium)
    }

    @ViewBuilder private var fallback: some View {
        switch size {
        case .card:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(address)
                    .font(.callout)
                    .lineLimit(5)
            }
        case .large:
            Image(systemName: "link")
                .font(.title)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }
}
