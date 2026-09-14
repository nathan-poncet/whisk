import ImageIO
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
    let onDragBegin: () -> Void
    /// One cursor at a time: while vim's search mode holds it, the ring
    /// stays off even though the selection survives underneath.
    var showsSelection = true

    static func == (lhs: ItemCardView, rhs: ItemCardView) -> Bool {
        lhs.card == rhs.card && lhs.showsSelection == rhs.showsSelection
    }

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

    private var selectedSide: CGFloat {
        card.isSelected ? 210 : 200
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        // The selection zoom needs both mechanisms at once: scaleEffect
        // grows the SwiftUI-drawn content (text, icons, ring), while the
        // frosted backdrop — an AppKit view that ignores transforms —
        // grows geometrically to the same size. Same factor, same curve:
        // they track. The outer slot stays constant so neighbors never
        // shift.
        .frame(width: 200, height: 200)
        .overlay(selectionRing)
        .scaleEffect(card.isSelected ? 210.0 / 200.0 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: card.isSelected)
        .frame(width: 210, height: 210)
        .background {
            Color.clear
                .frame(width: selectedSide, height: selectedSide)
                .liquidGlass(
                    in: Self.shape,
                    cornerRadius: 18,
                    tint: SourceAppStyle.resolve(bundleID: card.sourceBundleID)
                        .surfaceTint(dark: scheme == .dark)
                )
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: card.isSelected)
        }
        .contentShape(Rectangle())
        .grabPointer()
        .onDrag {
            onDragBegin()
            return Self.dragProvider(for: card.dragPayload)
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
        // One VoiceOver element per card: the presenter's label and value
        // say it all, the icons and texts inside are decorative.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityValue(card.accessibilityValue)
        .accessibilityHint(localized("Pastes this card"))
        .accessibilityAddTraits(card.isSelected && showsSelection ? [.isButton, .isSelected] : [.isButton])
        .accessibilityAction(.default, onSelect)
        .accessibilityAction(named: Text(card.isPinned ? localized("Unpin") : localized("Pin")), onTogglePin)
        .accessibilityAction(named: Text(localized("Delete")), onDelete)
    }

    @ViewBuilder private var selectionRing: some View {
        if card.isSelected && showsSelection {
            Self.shape
                .strokeBorder(Color.matcha, lineWidth: 2)
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            if let icon = SourceAppStyle.resolve(bundleID: card.sourceBundleID).icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Text(card.sourceLabel)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Spacer()
            if let position = card.stackPosition {
                HStack(spacing: 3) {
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 8))
                    Text("\(position)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                }
                .foregroundStyle(Color.matcha)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.matcha.opacity(0.18)))
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
                .font(.system(size: 12))
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
            LinkPreviewView(address: address, size: .card)
                .padding(.horizontal, 14)
        case .image(let data):
            if let image = Self.decodedImage(for: card.id, data: data) {
                // Color.clear takes exactly the offered space; the filling
                // image lives in an overlay so its ideal size can never
                // inflate the layout, and the clip keeps it inside.
                Color.clear
                    .overlay(
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 14)
            } else {
                Text(localized("Image"))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
            }
        case .files(let names, let overflow, let thumbnailPath):
            FilePreviewView(names: names, overflow: overflow, thumbnailPath: thumbnailPath, size: .card)
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

    /// Cards can be dragged straight into other applications; the presenter
    /// decided what travels, this only wraps it for the drag session.
    static func dragProvider(for payload: DragPayload) -> NSItemProvider {
        switch payload {
        case .text(let value):
            return NSItemProvider(object: value as NSString)
        case .link(let url):
            return NSItemProvider(object: url as NSURL)
        case .image(let data):
            if let image = NSImage(data: data) {
                return NSItemProvider(object: image)
            }
            return NSItemProvider()
        case .files(let paths):
            // One provider per drag session: the first file travels.
            if let path = paths.first,
                let provider = NSItemProvider(contentsOf: URL(fileURLWithPath: path))
            {
                return provider
            }
            return NSItemProvider()
        }
    }

    // Decoding image bytes during a body evaluation is visible as a flash,
    // so each card decodes once into a card-sized thumbnail — and the rail
    // prewarms the whole batch off the main thread, so a card entering the
    // scroll window arrives already decoded.
    private static let imageCache: NSCache<NSUUID, NSImage> = {
        let cache = NSCache<NSUUID, NSImage>()
        // A few screens' worth of thumbnails; the rest decode again on demand.
        cache.countLimit = 512
        return cache
    }()
    private static let thumbnailMaxDimension = 480
    private static let prewarmQueue = DispatchQueue(label: "whisk.card-prewarm", qos: .utility)

    /// Decodes the thumbnails of every image card in the background, ahead
    /// of the card being mounted.
    static func prewarm(_ cards: [CardViewState]) {
        for card in cards {
            guard case .image(let data) = card.preview else { continue }
            let key = card.id as NSUUID
            guard imageCache.object(forKey: key) == nil else { continue }
            prewarmQueue.async {
                guard imageCache.object(forKey: key) == nil,
                    let thumbnail = thumbnail(from: data)
                else { return }
                imageCache.setObject(thumbnail, forKey: key)
            }
        }
    }

    private static func decodedImage(for id: UUID, data: Data) -> NSImage? {
        let key = id as NSUUID
        if let cached = imageCache.object(forKey: key) {
            return cached
        }
        guard let thumbnail = thumbnail(from: data) else { return nil }
        imageCache.setObject(thumbnail, forKey: key)
        return thumbnail
    }

    private static func thumbnail(from data: Data) -> NSImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxDimension,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}
