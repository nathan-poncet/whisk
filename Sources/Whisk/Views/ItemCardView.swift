import WhiskKernel
import SwiftUI

struct ItemCardView: View {
    let item: ClipboardItem
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
            Button(item.isPinned ? "Unpin" : "Pin", action: onTogglePin)
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(item.sourceApp ?? kindLabel)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer()
            if item.isPinned {
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
        switch item.payload {
        case .text(let value):
            if let hex = HexColor(value) {
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(hex.color)
                        .frame(height: 90)
                    Text(hex.code)
                        .font(.callout.monospaced())
                }
                .padding(10)
            } else {
                Text(value)
                    .font(.callout)
                    .lineLimit(7)
                    .padding(10)
            }
        case .link(let url):
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                Text(url.absoluteString)
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
        case .fileReferences(let paths):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(paths.prefix(4), id: \.self) { path in
                    HStack(spacing: 6) {
                        Image(systemName: "doc")
                            .foregroundStyle(.secondary)
                        Text((path as NSString).lastPathComponent)
                            .font(.callout)
                            .lineLimit(1)
                    }
                }
                if paths.count > 4 {
                    Text("+ \(paths.count - 4) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
    }

    private var footer: some View {
        HStack {
            Text(Self.relativeFormatter.localizedString(for: item.copiedAt, relativeTo: Date()))
            Spacer()
            Text(kindLabel)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    private var kindLabel: String {
        switch item.payload {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        case .fileReferences: return "Files"
        }
    }

    private var kindColor: Color {
        switch item.payload {
        case .text: return .blue
        case .link: return .teal
        case .image: return .purple
        case .fileReferences: return .orange
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

struct HexColor {
    let color: Color
    let code: String

    init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: "^#?[0-9a-fA-F]{6}$", options: .regularExpression) != nil else { return nil }
        let hex = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        guard let value = UInt32(hex, radix: 16) else { return nil }
        code = "#" + hex.uppercased()
        color = Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
