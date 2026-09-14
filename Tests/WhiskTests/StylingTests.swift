import AppKit
import SwiftUI
import Testing

@testable import Whisk

@MainActor
@Suite struct SourceAppStyling {
    @Test func a_known_application_yields_its_icon_and_a_tint_and_is_resolved_once() {
        let first = SourceAppStyle.resolve(bundleID: "com.apple.finder")
        let second = SourceAppStyle.resolve(bundleID: "com.apple.finder")

        #expect(first.icon != nil)
        #expect(first.icon === second.icon)
        #expect(first.surfaceTint(dark: true) != first.surfaceTint(dark: false))
    }

    @Test func no_bundle_or_an_unknown_one_falls_back_to_the_gray_style() {
        let none = SourceAppStyle.resolve(bundleID: nil)
        let unknown = SourceAppStyle.resolve(bundleID: "com.example.never-installed")

        #expect(none.icon == nil)
        #expect(unknown.icon == nil)
        #expect(none.tint == unknown.tint)
    }
}

@Suite struct CategoryIconLoading {
    @Test func the_neovim_mark_ships_in_the_resource_bundle_and_loads_once() {
        let first = CategoryIcons.image(named: "nvim")
        let second = CategoryIcons.image(named: "nvim")

        #expect(first != nil)
        #expect(first === second)
    }

    @Test func a_missing_resource_is_nil_not_fatal() {
        #expect(CategoryIcons.image(named: "no-such-icon") == nil)
        #expect(CategoryIcons.image(named: "no-such-icon") == nil)
    }
}

@Suite struct ThemeColors {
    private func resolved(_ color: NSColor, under appearance: NSAppearance.Name) throws -> NSColor {
        let named = try #require(NSAppearance(named: appearance))
        var result: NSColor?
        named.performAsCurrentDrawingAppearance {
            result = color.usingColorSpace(.sRGB)
        }
        return try #require(result)
    }

    @Test func matcha_glows_pale_on_dark_and_deepens_on_light() throws {
        let dark = try resolved(.matcha, under: .darkAqua)
        let light = try resolved(.matcha, under: .aqua)

        #expect(dark.greenComponent > light.greenComponent)
        #expect(dark.brightnessComponent > light.brightnessComponent)
        #expect(Color.matcha == Color(nsColor: .matcha))
    }
}

@Suite struct CodeAttributing {
    @Test func tokens_recolor_their_ranges_and_out_of_range_tokens_are_ignored() {
        let text = "let x = 1"
        let tokens = [
            CodeToken(kind: .keyword, start: 0, length: 3),
            CodeToken(kind: .number, start: 8, length: 1),
            CodeToken(kind: .string, start: 20, length: 4),
        ]

        let attributed = CodeTextView.attributed(text, tokens: tokens)
        let runs = attributed.runs.map { run in
            (String(attributed[run.range].characters), run.appKit.foregroundColor)
        }

        #expect(runs.map(\.0) == ["let", " x = ", "1"])
        #expect(runs[0].1 == CodeTextView.color(for: .keyword))
        #expect(runs[1].1 == NSColor.labelColor)
        #expect(runs[2].1 == CodeTextView.color(for: .number))
        #expect(Set([CodeToken.Kind.keyword, .string, .comment, .number].map(CodeTextView.color(for:))).count == 4)
    }
}
