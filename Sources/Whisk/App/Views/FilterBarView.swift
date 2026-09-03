import AppKit
import SwiftUI

/// One chip row above the search field, three groups separated by thin
/// bars — the pinned toggle, then source applications, then content
/// categories. Several chips can be active at once; the focused chip is
/// the keyboard cursor (↑/↓ reach the row, ←/→ move, Return toggles) and
/// hovering moves that same focus with the mouse.
struct FilterBarView: View {
    @Environment(\.colorScheme) private var scheme
    let filters: FilterBarViewState
    /// One cursor at a time: vim's search mode swallows the chip focus.
    var cursorSuppressed = false
    let onToggleApp: (String) -> Void
    let onToggleKind: (String) -> Void
    let onFocusApp: (String) -> Void
    let onFocusKind: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters.pinned) { chip in
                        ChipButton(
                            chip: chip,
                            focusVisible: !cursorSuppressed,
                            onToggle: { onToggleKind(chip.id) },
                            onFocus: { onFocusKind(chip.id) }
                        ) {
                            HStack(spacing: 5) {
                                kindIcon(chip.id)
                                Text(chip.label)
                            }
                        }
                        .id(chip.id)
                    }
                    if !filters.pinned.isEmpty && !(filters.apps.isEmpty && filters.kinds.isEmpty) {
                        separator
                    }
                    ForEach(filters.apps) { chip in
                        ChipButton(
                            chip: chip,
                            baseTint: SourceAppStyle.resolve(bundleID: chip.sourceBundleID)
                                .surfaceTint(dark: scheme == .dark),
                            focusVisible: !cursorSuppressed,
                            onToggle: { onToggleApp(chip.id) },
                            onFocus: { onFocusApp(chip.id) }
                        ) {
                            HStack(spacing: 5) {
                                if let icon = SourceAppStyle.resolve(bundleID: chip.sourceBundleID).icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .frame(width: 17, height: 17)
                                }
                                Text(chip.label)
                            }
                        }
                        .id(chip.id)
                    }
                    if !filters.apps.isEmpty && !filters.kinds.isEmpty {
                        separator
                    }
                    ForEach(filters.kinds) { chip in
                        ChipButton(
                            chip: chip,
                            focusVisible: !cursorSuppressed,
                            onToggle: { onToggleKind(chip.id) },
                            onFocus: { onFocusKind(chip.id) }
                        ) {
                            HStack(spacing: 5) {
                                kindIcon(chip.id)
                                Text(chip.label)
                            }
                        }
                        .id(chip.id)
                    }
                }
                .padding(.vertical, 3)
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollClipDisabled()
            // Centered under the search capsule while the chips fit; the
            // anchor only matters when they don't scroll.
            .defaultScrollAnchor(.center)
            .onChange(of: filters.focusedChipID) { _, id in
                guard let id else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(id)
                }
            }
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.25))
            .frame(width: 1, height: 16)
            .padding(.horizontal, 4)
    }

    @ViewBuilder private func kindIcon(_ id: String) -> some View {
        if id == "code", let neovim = CategoryIcons.neovim {
            Image(nsImage: neovim)
                .resizable()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: kindSymbol(id))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private func kindSymbol(_ id: String) -> String {
        switch id {
        case "pinned": "pin.fill"
        case "text": "text.alignleft"
        case "code": "chevron.left.forwardslash.chevron.right"
        case "color": "paintpalette"
        case "link": "link"
        case "image": "photo"
        case "files": "folder"
        default: "square"
        }
    }
}

/// One chip. Like the cards: hovering moves the shared keyboard focus onto
/// it, and focus or an active filter zooms it slightly.
private struct ChipButton<Label: View>: View {
    let chip: FilterChip
    var baseTint: Color?
    var focusVisible = true
    let onToggle: () -> Void
    let onFocus: () -> Void
    @ViewBuilder let label: () -> Label

    private var isFocused: Bool {
        chip.isFocused && focusVisible
    }

    private var zoomed: Bool {
        isFocused || chip.isActive
    }

    var body: some View {
        Button(action: onToggle) {
            label()
        }
        .buttonStyle(FilterChipStyle(isActive: chip.isActive, isFocused: isFocused))
        .linkPointer()
        .scaleEffect(zoomed ? 1.06 : 1)
        // The frosted capsule is an AppKit view and ignores transforms, so
        // it grows geometrically in a measured background — oversize does
        // not push neighbors — while the content scales above it.
        .background {
            GeometryReader { proxy in
                Color.clear
                    .liquidGlass(
                        in: Capsule(),
                        tint: chip.isActive ? Color.matcha.opacity(0.28) : baseTint
                    )
                    .frame(
                        width: proxy.size.width * (zoomed ? 1.06 : 1),
                        height: proxy.size.height * (zoomed ? 1.06 : 1)
                    )
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .animation(.easeOut(duration: 0.14), value: isFocused)
        .animation(.easeOut(duration: 0.14), value: chip.isActive)
        .onContinuousHover { phase in
            if case .active = phase, MouseActivity.movedRecently {
                onFocus()
            }
        }
    }
}

private struct FilterChipStyle: ButtonStyle {
    let isActive: Bool
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(isActive ? .semibold : .regular))
            .foregroundStyle(isActive ? Color.matcha : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(
                Capsule().strokeBorder(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }

    private var borderColor: Color {
        if isFocused {
            return Color.matcha
        }
        if isActive {
            return Color.matcha.opacity(0.8)
        }
        return .clear
    }
}
