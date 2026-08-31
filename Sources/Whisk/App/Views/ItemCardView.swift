import SwiftUI

struct ItemCardView: View {
    let card: CardViewState
    let onSelect: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

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
        .overlay(
            Self.shape.strokeBorder(.white.opacity(isHovering ? 0.30 : 0.10), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1)
        .animation(.easeOut(duration: 0.16), value: isHovering)
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
        case .link(let address):
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(address)
                    .font(.callout)
                    .lineLimit(5)
            }
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
        case .files(let names, let overflow):
            VStack(alignment: .leading, spacing: 5) {
                ForEach(names, id: \.self) { name in
                    HStack(spacing: 6) {
                        Image(systemName: "doc")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(name)
                            .font(.callout)
                            .lineLimit(1)
                    }
                }
                if overflow > 0 {
                    Text("+ \(overflow) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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
