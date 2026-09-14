import Foundation
import Testing
@testable import Whisk

@Suite struct HistoryPresenterBehaviour {
    let presenter = HistoryPresenter()
    let now = Date(timeIntervalSince1970: 1_700_000_060)

    @Test func a_color_text_presents_as_a_swatch_labeled_as_copied() {
        let state = presenter.present(items: [anItem(.text(" #7d9471 "))], query: "", now: now)

        let expected = CardPreview.color(
            code: "#7d9471",
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
        #expect(
            state.cards.first?.preview
                == .files(
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
            let insideComment =
                commentToken.map { keyword.start >= $0.start && keyword.start < $0.start + $0.length } ?? false
            let insideString =
                stringToken.map { keyword.start >= $0.start && keyword.start < $0.start + $0.length } ?? false
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

    @Test func the_chip_row_renders_in_the_order_it_is_steered() throws {
        let slack = try #require(SourceApp(name: "Slack", bundleID: "com.slack"))
        let row = ChipEntry.row(hasPinned: true, sources: [slack], categories: [.code, .text])

        let state = presenter.present(
            items: [], query: "", now: now,
            filters: FilterContext(chips: row, activeCategories: [.code], focusedChipID: "com.slack")
        )

        #expect(row.map(\.id) == ["pinned", "com.slack", "code", "text"])
        #expect(state.filters.pinned.map(\.id) == ["pinned"])
        #expect(state.filters.apps.map(\.label) == ["Slack"])
        #expect(state.filters.apps.first?.isFocused == true)
        #expect(state.filters.kinds.map(\.isActive) == [true, false])
        #expect(state.filters.focusedChipID == "com.slack")
    }

    @Test func chips_carry_the_icon_they_wear() throws {
        let slack = try #require(SourceApp(name: "Slack", bundleID: "com.slack"))
        let row = ChipEntry.row(hasPinned: true, sources: [slack], categories: [.code, .image])

        let state = presenter.present(items: [], query: "", now: now, filters: FilterContext(chips: row))

        #expect(state.filters.pinned.first?.icon == .symbol("pin.fill"))
        #expect(state.filters.apps.first?.icon == nil)
        #expect(
            state.filters.kinds.map(\.icon) == [
                .resource("nvim", fallback: "chevron.left.forwardslash.chevron.right"), .symbol("photo"),
            ])
    }

    @Test func an_empty_rail_explains_itself() {
        let untouched = presenter.present(items: [], query: "", now: now)
        let searched = presenter.present(items: [], query: "zzz", now: now)
        let narrowed = presenter.present(
            items: [], query: "", now: now, filters: FilterContext(chips: [.pinned], pinnedOnly: true))
        let populated = presenter.present(items: [anItem(.text("a"))], query: "", now: now)

        #expect(untouched.emptyMessage == "Copy something to get started")
        #expect(searched.emptyMessage == "No matches")
        #expect(narrowed.emptyMessage == "No matches")
        #expect(populated.emptyMessage == nil)
    }

    @Test func the_selected_card_is_the_one_the_preview_follows() {
        let items = [anItem(.text("first")), anItem(.text("second"))]

        let state = presenter.present(items: items, query: "", now: now, selectedID: items[1].id)
        let unfocused = presenter.present(items: items, query: "", now: now, selectedID: nil)

        #expect(state.selectedCard?.preview == .text("second"))
        #expect(unfocused.selectedCard == nil)
    }

    @Test func cards_describe_themselves_for_voiceover() {
        let pinned = anItem(.text("hello\n  world"), from: "Safari", at: now, pinned: true)
        let files = anItem(.fileReferences(["/tmp/a.txt", "/tmp/b.txt"]), from: "Finder", at: now)
        let picture = anItem(.image(Data([0x01])), from: "Preview", at: now)

        let state = presenter.present(items: [pinned, files, picture], query: "", now: now, stack: [files.id])

        #expect(state.cards[0].accessibilityLabel == "Safari, text, hello world")
        #expect(state.cards[0].accessibilityValue == "Pinned card, now")
        #expect(state.cards[1].accessibilityLabel == "Finder, files, a.txt, b.txt")
        #expect(state.cards[1].accessibilityValue == "Paste stack position 1, now")
        #expect(state.cards[2].accessibilityLabel == "Preview, image")
        #expect(state.cards[2].accessibilityValue == "now")
    }

    @Test func a_long_text_is_cut_short_for_voiceover() {
        let long = String(repeating: "word ", count: 60)

        let state = presenter.present(items: [anItem(.text(long), from: "Notes", at: now)], query: "", now: now)

        let label = state.cards[0].accessibilityLabel
        #expect(label.hasPrefix("Notes, text, word word"))
        #expect(label.hasSuffix("…"))
        #expect(label.count < 170)
    }

    @Test func chips_describe_their_group_for_voiceover() throws {
        let slack = try #require(SourceApp(name: "Slack", bundleID: "com.slack"))
        let row = ChipEntry.row(hasPinned: true, sources: [slack], categories: [.code])

        let state = presenter.present(items: [], query: "", now: now, filters: FilterContext(chips: row))

        #expect(state.filters.pinned.first?.accessibilityLabel == "Pinned items, filter")
        #expect(state.filters.apps.first?.accessibilityLabel == "Slack, application filter")
        #expect(state.filters.kinds.first?.accessibilityLabel == "Code, kind filter")
    }

    @Test func what_leaves_on_a_drag_is_the_item_not_the_drawing() throws {
        let url = try #require(URL(string: "https://example.com"))
        let items = [
            anItem(.text("plain")), anItem(.text(" #7d9471 ")), anItem(.link(url)), anItem(.image(Data([0x01]))),
            anItem(.fileReferences(["/tmp/a.txt", "/tmp/b.txt"])),
        ]

        let state = presenter.present(items: items, query: "", now: now)

        #expect(
            state.cards.map(\.dragPayload) == [
                .text("plain"), .text("#7d9471"), .link(url), .image(Data([0x01])),
                .files(["/tmp/a.txt", "/tmp/b.txt"]),
            ])
    }

    @Test func past_the_cache_limit_the_purge_keeps_what_is_on_screen_and_lets_the_rest_go() {
        let old = Date(timeIntervalSince1970: 1_600_000_000)
        let many = (0..<2_100).map { anItem(.text("entry \($0)"), at: old.addingTimeInterval(Double($0))) }
        let few = (0..<10).map { anItem(.text("later \($0)"), at: old) }

        let first = presenter.present(items: many, query: "", now: now)
        let second = presenter.present(items: many, query: "", now: now)
        #expect(first.cards.count == 2_100)
        #expect(first.cards.last?.preview == .text("entry 2099"))
        #expect(first.cards.map(\.timeLabel) == second.cards.map(\.timeLabel))
        #expect(presenter.cachedPreviewCount == 2_100)

        let next = presenter.present(items: few, query: "", now: now)

        #expect(next.cards.count == 10)
        #expect(presenter.cachedPreviewCount == 10)
    }

    @Test func a_chip_bar_knows_when_it_has_nothing_to_show() throws {
        let slack = try #require(SourceApp(name: "Slack", bundleID: "com.slack"))
        let row = ChipEntry.row(hasPinned: false, sources: [slack], categories: [])

        let bare = presenter.present(items: [], query: "", now: now)
        let chipped = presenter.present(items: [], query: "", now: now, filters: FilterContext(chips: row))

        #expect(bare.filters.isEmpty)
        #expect(FilterBarViewState.empty.isEmpty)
        #expect(!chipped.filters.isEmpty)
    }

    @Test func a_live_query_marks_where_its_words_landed_in_utf16_offsets() {
        let items = [anItem(.text("héllo 😀 world"), at: now), anItem(.text("func run() { start() }"), at: now)]

        let searched = presenter.present(items: items, query: "world run", now: now)
        let idle = presenter.present(items: items, query: "", now: now)
        let gated = presenter.present(items: items, query: "app:slack", now: now)

        #expect(searched.cards[0].matches == [MatchSpan(start: 9, length: 5)])
        #expect(searched.cards[1].matches == [MatchSpan(start: 5, length: 3)])
        #expect(idle.cards.allSatisfy { $0.matches.isEmpty })
        #expect(gated.cards.allSatisfy { $0.matches.isEmpty })
    }

    @Test func scattered_hits_become_one_span_per_run_and_only_text_is_marked() throws {
        let url = try #require(URL(string: "https://example.com/ac"))
        let items = [anItem(.text("abcabc"), at: now), anItem(.link(url), at: now)]

        let state = presenter.present(items: items, query: "ac", now: now)

        #expect(state.cards[0].matches == [MatchSpan(start: 0, length: 1), MatchSpan(start: 2, length: 1)])
        #expect(state.cards[1].matches.isEmpty)
    }

    @Test func cards_say_whether_they_save_and_which_application_they_belong_to() throws {
        let url = try #require(URL(string: "https://example.com"))
        let items = [
            anItem(.text("t"), from: "Slack", bundle: "com.slack"), anItem(.link(url), from: "Safari"),
            anItem(.image(Data([0x01])), from: nil), anItem(.fileReferences(["/tmp/a"]), from: "Finder"),
        ]

        let state = presenter.present(items: items, query: "", now: now)

        #expect(state.cards.map(\.saveable) == [true, true, true, false])
        #expect(state.cards.map(\.sourceKey) == ["com.slack", "Safari", nil, "Finder"])
        #expect(SaveToDisk.proposal(for: .text("hi"))?.name == "Clipboard.txt")
        #expect(SaveToDisk.proposal(for: .link(url))?.data == Data("https://example.com".utf8))
        #expect(SaveToDisk.proposal(for: .image(Data([0x01])))?.name == "Clipboard.png")
        #expect(SaveToDisk.proposal(for: .files(["/tmp/a"])) == nil)
    }

    @Test func every_transform_has_a_distinct_menu_label() {
        let labels = TextTransform.allCases.map(\.label)

        #expect(labels.allSatisfy { !$0.isEmpty })
        #expect(Set(labels).count == labels.count)
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

    @Test func a_fresh_item_reads_now_so_selection_moves_do_not_churn_labels() {
        let copied = Date(timeIntervalSince1970: 1_700_000_030)
        let first = presenter.present(items: [anItem(.text("a"), at: copied)], query: "", now: now)
        let second = presenter.present(
            items: [anItem(.text("a"), at: copied)],
            query: "",
            now: now.addingTimeInterval(5)
        )

        #expect(first.cards.first?.timeLabel == "now")
        #expect(first.cards.first?.timeLabel == second.cards.first?.timeLabel)
    }
}
