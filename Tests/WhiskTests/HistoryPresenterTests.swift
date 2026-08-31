import Foundation
import Testing
@testable import Whisk

@Suite struct HistoryPresenterBehaviour {
    let presenter = HistoryPresenter()
    let now = Date(timeIntervalSince1970: 1_700_000_060)

    @Test func a_hex_color_text_presents_as_a_swatch() {
        let state = presenter.present(items: [anItem(.text(" #7d9471 "))], query: "", now: now)

        let expected = CardPreview.color(
            code: "#7D9471",
            rgb: RGB(red: Double(0x7D) / 255, green: Double(0x94) / 255, blue: Double(0x71) / 255)
        )
        #expect(state.cards.first?.preview == expected)
    }

    @Test func ordinary_text_stays_text() {
        let state = presenter.present(items: [anItem(.text("#7D947"))], query: "", now: now)

        #expect(state.cards.first?.preview == .text("#7D947"))
    }

    @Test func files_beyond_four_present_an_overflow_count() {
        let paths = (1...6).map { "/tmp/deep/dir/file-\($0).txt" }
        let state = presenter.present(items: [anItem(.fileReferences(paths))], query: "", now: now)

        let expectedNames = ["file-1.txt", "file-2.txt", "file-3.txt", "file-4.txt"]
        #expect(state.cards.first?.preview == .files(
            names: expectedNames,
            overflow: 2,
            thumbnailPath: "/tmp/deep/dir/file-1.txt"
        ))
    }

    @Test func swift_like_text_presents_as_highlighted_code() throws {
        let snippet = """
        func greet(name: String) -> String {
            // says hello
            return "Hello there"
        }
        """
        let state = presenter.present(items: [anItem(.text(snippet))], query: "", now: now)

        guard case .code(let text, let tokens) = state.cards.first?.preview else {
            Issue.record("expected a code preview")
            return
        }
        #expect(text == snippet)
        let kinds = Set(tokens.map(\.kind))
        #expect(kinds.contains(.keyword))
        #expect(kinds.contains(.comment))
        #expect(kinds.contains(.string))
        #expect(state.cards.first?.kindLabel == "code")
    }

    @Test func a_single_line_of_code_is_still_detected() {
        let line = "let keyCode = KeyboardLayout.keyCode(for: 9)"
        let state = presenter.present(items: [anItem(.text(line))], query: "", now: now)

        guard case .code = state.cards.first?.preview else {
            Issue.record("expected a code preview")
            return
        }
    }

    @Test func prose_stays_plain_text() {
        let prose = "Let me know when you arrive (soon). We can grab coffee and talk about the plan."
        let state = presenter.present(items: [anItem(.text(prose))], query: "", now: now)

        #expect(state.cards.first?.preview == .text(prose))
        #expect(state.cards.first?.kindLabel == "text")
    }

    @Test func keywords_inside_strings_and_comments_stay_claimed_by_them() {
        let snippet = """
        // let this comment mention func and class
        let label = "if you return"
        """
        let tokens = CodeHighlighter.tokens(in: snippet)

        let commentToken = tokens.first { $0.kind == .comment }
        let stringToken = tokens.first { $0.kind == .string }
        #expect(commentToken != nil)
        #expect(stringToken != nil)
        for keyword in tokens.filter({ $0.kind == .keyword }) {
            let insideComment = commentToken.map { keyword.start >= $0.start && keyword.start < $0.start + $0.length } ?? false
            let insideString = stringToken.map { keyword.start >= $0.start && keyword.start < $0.start + $0.length } ?? false
            #expect(!insideComment && !insideString)
        }
    }

    @Test func an_item_without_a_source_falls_back_to_its_kind() {
        let state = presenter.present(items: [anItem(.text("hello"), from: nil)], query: "", now: now)

        #expect(state.cards.first?.sourceLabel == "Text")
        #expect(state.cards.first?.kindLabel == "text")
    }

    @Test func a_link_presents_its_full_address() throws {
        let url = try #require(URL(string: "https://example.com/path?q=1"))
        let state = presenter.present(items: [anItem(.link(url))], query: "", now: now)

        #expect(state.cards.first?.preview == .link("https://example.com/path?q=1"))
        #expect(state.cards.first?.kindLabel == "link")
    }

    @Test func the_count_label_is_singular_for_one_item() {
        let one = presenter.present(items: [anItem(.text("a"))], query: "", now: now)
        let two = presenter.present(items: [anItem(.text("a")), anItem(.text("b"))], query: "", now: now)

        #expect(one.countLabel == "1 item")
        #expect(two.countLabel == "2 items")
    }

    @Test func time_labels_are_present_for_every_card() {
        let state = presenter.present(
            items: [anItem(.text("a"), at: Date(timeIntervalSince1970: 1_700_000_000))],
            query: "",
            now: now
        )

        #expect(state.cards.allSatisfy { !$0.timeLabel.isEmpty })
    }
}
