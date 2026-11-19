import SwiftUI

/// Asks for the pasteboard where the system guards it: why Whisk needs
/// it, the steps the system leaves to the user, and the confirmation once
/// they are done. It follows the presenter's state, so allowing Whisk in
/// System Settings shows here without a relaunch.
struct ClipboardAccessView: View {
    @ObservedObject var store: HistoryViewStateStore
    let onOpenSettings: () -> Void
    let onClose: () -> Void

    var body: some View {
        let state = store.state.accessWindow
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: state.symbol)
                    .font(.system(size: 32))
                    .frame(width: 48, height: 48)
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.title)
                        .font(.title2.weight(.semibold))
                    Text(state.message)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(Array(state.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "\(index + 1).circle.fill")
                        .font(.title3)
                        .frame(width: 48)
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).font(.headline)
                        Text(step.detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack {
                if let dismiss = state.dismissButton {
                    Button(dismiss, action: onClose)
                }
                Spacer()
                Button(state.primaryButton) {
                    switch state.primaryAction {
                    case .openSettings: onOpenSettings()
                    case .close: onClose()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
