import AppKit
import SwiftUI

/// First-run walkthrough: what Whisk does and why it asks for
/// Accessibility access, instead of a bare system prompt.
struct OnboardingView: View {
    let toggleShortcut: String
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading) {
                    Text(localized("Welcome to Whisk"))
                        .font(.title2.weight(.semibold))
                    Text(localized("Your clipboard, remembered."))
                        .foregroundStyle(.secondary)
                }
            }

            step(
                symbol: "keyboard",
                title: String(format: localized("Press %@"), toggleShortcut),
                text: localized(
                    "A panel slides up with everything you copied — search it, filter it, arrow through it.")
            )
            step(
                symbol: "hand.raised",
                title: localized("Everything stays local"),
                text: localized(
                    "History lives on this Mac. Concealed content from password managers is never recorded.")
            )
            step(
                symbol: "accessibility",
                title: localized("Paste in place (optional)"),
                text: localized(
                    "To paste straight into the field you were typing in, Whisk needs Accessibility access.")
                    + " " + localized("Without it, a selection still lands on the clipboard for a manual ⌘V.")
            )

            HStack {
                Button(localized("Open Accessibility Settings")) {
                    if let url = URL(
                        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
                    {
                        NSWorkspace.shared.open(url)
                    }
                }
                Spacer()
                Button(localized("Get Started")) {
                    onContinue()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    private func step(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
