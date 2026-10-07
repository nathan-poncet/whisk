import AppKit
import SwiftUI

/// First-run walkthrough: the shortcut, where the history lives, and
/// one habit worth picking up. The Accessibility prompt is not here: the
/// system asks for it the first time a card is pasted.
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
                symbol: "pin",
                title: localized("Pin what you always need"),
                text: localized(
                    "Pinned cards survive Clear and retention, and one chip shows only them.")
            )

            HStack {
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
