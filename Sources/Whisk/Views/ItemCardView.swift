import SwiftUI
import WhiskAdapters

struct ItemCardView: View {
    let card: CardViewState
    let onSelect: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .frame(width: 230)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.quaternary)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button(card.isPinned ? "Unpin" : "Pin", action: onTogglePin)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(card.sourceLabel)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer()
            if card.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(kindColor)
    }

    @ViewBuilder private var preview: some View {
        switch card.preview {
        case .text(let value):
            Text(value)
                .font(.callout)
                .lineLimit(7)
                .padding(10)
        case .color(let code, let rgb):
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(red: rgb.red, green: rgb.green, blue: rgb.blue))
                    .frame(height: 90)
                Text(code)
                    .font(.callout.monospaced())
            }
            .padding(10)
        case .link(let address):
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                Text(address)
                    .font(.callout)
                    .lineLimit(5)
            }
            .padding(10)
        case .image(let data):
            if let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Text("Image")
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
        case .files(let names, let overflow):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(names, id: \.self) { name in
                    HStack(spacing: 6) {
                        Image(systemName: "doc")
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
            .padding(10)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var kindColor: Color {
        switch card.preview {
        case .text, .color: return .blue
        case .link: return .teal
        case .image: return .purple
        case .files: return .orange
        }
    }
}
