import AppKit
import SwiftUI

/// Two stacked chip rows above the search field — source applications on
/// top, content categories below. The active chip filters the rail; the
/// focused chip is the keyboard cursor (↑/↓ reach the rows, ←/→ move,
/// Return toggles) and hovering moves that same focus with the mouse.
struct FilterBarView: View {
    let filters: FilterBarViewState
    let onToggleApp: (String) -> Void
    let onToggleKind: (String) -> Void
    let onFocusApp: (String) -> Void
    let onFocusKind: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !filters.apps.isEmpty {
                appsRow
            }
            if !filters.kinds.isEmpty {
                kindsRow
            }
        }
    }

    private var appsRow: some View {
        chipRow(filters.apps, toggle: onToggleApp, focus: onFocusApp) { chip in
            HStack(spacing: 5) {
                if let icon = SourceAppStyle.resolve(bundleID: chip.sourceBundleID).icon {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 14, height: 14)
                }
                Text(chip.label)
            }
        }
    }

    private var kindsRow: some View {
        chipRow(filters.kinds, toggle: onToggleKind, focus: onFocusKind) { chip in
            HStack(spacing: 5) {
                kindIcon(chip.id)
                Text(chip.label)
            }
        }
    }

    private func chipRow(
        _ chips: [FilterChip],
        toggle: @escaping (String) -> Void,
        focus: @escaping (String) -> Void,
        @ViewBuilder label: @escaping (FilterChip) -> some View
    ) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips) { chip in
                        ChipButton(
                            chip: chip,
                            onToggle: { toggle(chip.id) },
                            onFocus: { focus(chip.id) }
                        ) {
                            label(chip)
                        }
                        .id(chip.id)
                    }
                }
                .padding(.vertical, 3)
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
            .scrollClipDisabled()
            .onChange(of: filters.focusedChipID) { _, id in
                guard let id, chips.contains(where: { $0.id == id }) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(id)
                }
            }
        }
    }

    @ViewBuilder private func kindIcon(_ id: String) -> some View {
        if id == "code", let neovim = CategoryIcons.neovim {
            Image(nsImage: neovim)
                .resizable()
                .frame(width: 13, height: 13)
        } else {
            Image(systemName: kindSymbol(id))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func kindSymbol(_ id: String) -> String {
        switch id {
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
    let onToggle: () -> Void
    let onFocus: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: onToggle) {
            label()
        }
        .buttonStyle(FilterChipStyle(isActive: chip.isActive, isFocused: chip.isFocused))
        .scaleEffect(chip.isFocused || chip.isActive ? 1.06 : 1)
        .animation(.easeOut(duration: 0.14), value: chip.isFocused)
        .animation(.easeOut(duration: 0.14), value: chip.isActive)
        .onHover { hovering in
            if hovering {
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
            .font(.caption.weight(isActive ? .semibold : .regular))
            .foregroundStyle(isActive ? Color.accentColor : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .liquidGlass(in: Capsule(), tint: isActive ? Color.accentColor.opacity(0.28) : nil)
            .overlay(
                Capsule().strokeBorder(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }

    private var borderColor: Color {
        if isFocused {
            return .accentColor
        }
        if isActive {
            return .accentColor.opacity(0.8)
        }
        return .white.opacity(0.10)
    }
}
