import SwiftUI

/// The chip bar under the search field: one glass chip per source
/// application and per content category; the active chip filters the rail.
struct FilterBarView: View {
    let filters: FilterBarViewState
    let onToggleApp: (String) -> Void
    let onToggleKind: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters.apps) { chip in
                    Button {
                        onToggleApp(chip.id)
                    } label: {
                        HStack(spacing: 5) {
                            if let icon = SourceAppStyle.resolve(bundleID: chip.sourceBundleID).icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 14, height: 14)
                            }
                            Text(chip.label)
                        }
                    }
                    .buttonStyle(FilterChipStyle(isActive: chip.isActive))
                }
                if !filters.apps.isEmpty && !filters.kinds.isEmpty {
                    Rectangle()
                        .fill(.white.opacity(0.15))
                        .frame(width: 1, height: 14)
                }
                ForEach(filters.kinds) { chip in
                    Button {
                        onToggleKind(chip.id)
                    } label: {
                        Text(chip.label)
                    }
                    .buttonStyle(FilterChipStyle(isActive: chip.isActive))
                }
            }
            .padding(.vertical, 2)
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
    }
}

private struct FilterChipStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(isActive ? .semibold : .regular))
            .foregroundStyle(isActive ? Color.accentColor : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .liquidGlass(in: Capsule(), tint: isActive ? Color.accentColor.opacity(0.28) : nil)
            .overlay(
                Capsule().strokeBorder(
                    isActive ? Color.accentColor.opacity(0.8) : .white.opacity(0.10),
                    lineWidth: 1
                )
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
