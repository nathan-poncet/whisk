import SwiftUI

/// Equatable on the view state alone: the action closures never compare
/// equal, and without this every card would rebuild (and visibly flash) on
/// each selection move.
struct ItemCardView: View, Equatable {
    let card: CardViewState
    let onSelect: () -> Void
    let onHighlight: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    static func == (lhs: ItemCardView, rhs: ItemCardView) -> Bool {
        lhs.card == rhs.card
    }

    private static let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .frame(width: 230)
        .liquidGlass(
            in: Self.shape,
            tint: SourceAppStyle.resolve(bundleID: card.sourceBundleID).tint.opacity(0.32)
        )
        .overlay(selectionRing)
        // The scale sits below contentShape, so the selected card's hit
        // area grows with it — natural hysteresis for hover selection.
        .scaleEffect(card.isSelected ? 1.04 : 1)
        .animation(.easeOut(duration: 0.16), value: card.isSelected)
        .contentShape(Self.shape)
        .onDrag {
            Self.dragProvider(for: card.preview)
        }
        .onTapGesture(perform: onSelect)
        // Continuous, not enter/exit: after a keyboard scroll parks a card
        // under the pointer, the very first real movement inside it must
        // reclaim the selection — without crossing a card edge first.
        .onContinuousHover { phase in
            if case .active = phase, MouseActivity.movedRecently {
                onHighlight()
            }
        }
        .contextMenu {
            Button(card.isPinned ? localized("Unpin") : localized("Pin"), action: onTogglePin)
            Button(localized("Delete"), role: .destructive, action: onDelete)
        }
    }

    @ViewBuilder private var selectionRing: some View {
        if card.isSelected {
            ZStack {
                Self.shape
                    .stroke(Color.accentColor.opacity(0.55), lineWidth: 7)
                    .blur(radius: 7)
                Self.shape
                    .strokeBorder(Color.accentColor, lineWidth: 3)
            }
        } else {
            Self.shape.strokeBorder(.white.opacity(0.10), lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            if let icon = SourceAppStyle.resolve(bundleID: card.sourceBundleID).icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Text(card.sourceLabel)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer()
            if let position = card.stackPosition {
                HStack(spacing: 3) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 8))
                    Text("\(position)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor.opacity(0.18)))
            }
            if card.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder private var preview: some View {
        switch card.preview {
        case .text(let value):
            Text(value)
                .font(.callout)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .mask(bottomFade)
        case .color(let code, let rgb):
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: rgb.red, green: rgb.green, blue: rgb.blue).opacity(rgb.alpha))
                    .frame(height: 86)
                Text(code)
                    .font(.callout.monospaced())
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
        case .code(let text, let tokens):
            CodeTextView(text: text, tokens: tokens, lineLimit: nil)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .mask(bottomFade)
        case .link(let address):
            LinkCardPreview(address: address)
                .padding(.horizontal, 14)
        case .image(let data):
            if let image = Self.decodedImage(for: card.id, data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 14)
            } else {
                Text(localized("Image"))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
            }
        case .files(let names, let overflow, let thumbnailPath):
            FileCardPreview(names: names, overflow: overflow, thumbnailPath: thumbnailPath)
                .padding(.horizontal, 14)
        }
    }

    /// Overflowing text melts into the card's bottom edge instead of being
    /// chopped: full opacity everywhere but the last stretch, which fades
    /// to nothing. Short content never reaches the fade zone.
    private var bottomFade: some View {
        VStack(spacing: 0) {
            Rectangle()
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 26)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Text(card.timeLabel)
            Spacer()
            if let detail = card.detailLabel {
                Text(detail)
                Text("·")
            }
            Text(card.kindLabel)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    /// Cards can be dragged straight into other applications.
    private static func dragProvider(for preview: CardPreview) -> NSItemProvider {
        switch preview {
        case .text(let value), .code(let value, _):
            return NSItemProvider(object: value as NSString)
        case .color(let code, _):
            return NSItemProvider(object: code as NSString)
        case .link(let address):
            if let url = URL(string: address) {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider(object: address as NSString)
        case .image(let data):
            if let image = NSImage(data: data) {
                return NSItemProvider(object: image)
            }
            return NSItemProvider()
        case .files(_, _, let thumbnailPath):
            if let path = thumbnailPath,
                let provider = NSItemProvider(contentsOf: URL(fileURLWithPath: path))
            {
                return provider
            }
            return NSItemProvider()
        }
    }

    // Decoding image bytes on every body evaluation is visible as a flash,
    // and the rail renders eagerly — so each card decodes once and keeps a
    // card-sized thumbnail, never the full bitmap.
    private static let imageCache = NSCache<NSUUID, NSImage>()
    private static let thumbnailMaxDimension: CGFloat = 480

    private static func decodedImage(for id: UUID, data: Data) -> NSImage? {
        let key = id as NSUUID
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let image = NSImage(data: data) else { return nil }
        let thumbnail = downscaled(image)
        imageCache.setObject(thumbnail, forKey: key)
        return thumbnail
    }

    private static func downscaled(_ image: NSImage) -> NSImage {
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > thumbnailMaxDimension, longestSide > 0 else { return image }
        let scale = thumbnailMaxDimension / longestSide
        let target = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let thumbnail = NSImage(size: target)
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: target))
        thumbnail.unlockFocus()
        return thumbnail
    }
}

/// Link card: fetched page metadata when available, the bare address until
/// then (or when the fetch failed).
private struct LinkCardPreview: View {
    let address: String
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
        VStack(alignment: .leading, spacing: 7) {
            if let image = preview.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            HStack(alignment: .top, spacing: 6) {
                if let icon = preview.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 15, height: 15)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                Text(preview.title ?? address)
                    .font(.callout.weight(.medium))
                    .lineLimit(preview.image == nil ? 4 : 2)
            }
            if preview.title != nil, let host = preview.host {
                Text(host)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fallback: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(address)
                .font(.callout)
                .lineLimit(5)
        }
    }
}

/// File card: a QuickLook thumbnail of the first file (file-type icon until
/// it arrives), then the file names.
private struct FileCardPreview: View {
    let names: [String]
    let overflow: Int
    let thumbnailPath: String?
    @ObservedObject private var store = FileThumbnailStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let path = thumbnailPath {
                Image(nsImage: store.thumbnail(for: path) ?? NSWorkspace.shared.icon(forFile: path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            ForEach(names, id: \.self) { name in
                HStack(spacing: 6) {
                    Image(systemName: "doc")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(name)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
            if overflow > 0 {
                Text(localized("+ \(overflow) more"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if let path = thumbnailPath {
                store.load(path)
            }
        }
    }
}
