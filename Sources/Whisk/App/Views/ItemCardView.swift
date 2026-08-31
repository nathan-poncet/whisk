import SwiftUI

/// Equatable on the view state alone: the action closures never compare
/// equal, and without this every card would rebuild (and visibly flash) on
/// each selection move.
struct ItemCardView: View, Equatable {
    let card: CardViewState
    let onSelect: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

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
            tint: SourceAppStyle.resolve(bundleID: card.sourceBundleID).tint.opacity(0.32),
            interactive: true
        )
        .overlay(selectionRing)
        .shadow(
            color: card.isSelected ? Color.accentColor.opacity(0.55) : .clear,
            radius: card.isSelected ? 14 : 0
        )
        .scaleEffect(card.isSelected ? 1.05 : (isHovering ? 1.02 : 1))
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .animation(.easeOut(duration: 0.16), value: card.isSelected)
        .contentShape(Self.shape)
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button(card.isPinned ? "Unpin" : "Pin", action: onTogglePin)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    @ViewBuilder private var selectionRing: some View {
        if card.isSelected {
            Self.shape.strokeBorder(Color.accentColor, lineWidth: 3)
        } else {
            Self.shape.strokeBorder(.white.opacity(isHovering ? 0.30 : 0.10), lineWidth: 1)
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
                .lineLimit(6)
                .padding(.horizontal, 14)
        case .color(let code, let rgb):
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: rgb.red, green: rgb.green, blue: rgb.blue))
                    .frame(height: 86)
                Text(code)
                    .font(.callout.monospaced())
            }
            .padding(.horizontal, 14)
        case .code(let text, let tokens):
            CodeTextView(text: text, tokens: tokens)
                .padding(.horizontal, 14)
        case .link(let address):
            LinkCardPreview(address: address)
                .padding(.horizontal, 14)
        case .image(let data):
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 14)
            } else {
                Text("Image")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
            }
        case .files(let names, let overflow, let thumbnailPath):
            FileCardPreview(names: names, overflow: overflow, thumbnailPath: thumbnailPath)
                .padding(.horizontal, 14)
        }
    }

    private var footer: some View {
        HStack {
            Text(card.timeLabel)
            Spacer()
            Text(card.kindLabel)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 12)
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
                Text("+ \(overflow) more")
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
