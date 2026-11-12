import Testing

@testable import Whisk

@Suite struct FuzzyMatching {
    @Test func the_pattern_must_appear_in_order() {
        #expect(FuzzyMatch.score(pattern: "abc", in: "a-b-c") != nil)
        #expect(FuzzyMatch.score(pattern: "cba", in: "a-b-c") == nil)
        #expect(FuzzyMatch.score(pattern: "abcd", in: "abc") == nil)
        #expect(FuzzyMatch.score(pattern: "", in: "anything") == 0)
    }

    @Test func a_lowercase_pattern_ignores_case_and_an_uppercase_one_does_not() {
        #expect(FuzzyMatch.score(pattern: "ab", in: "AB") != nil)
        #expect(FuzzyMatch.score(pattern: "AB", in: "ab") == nil)
        #expect(FuzzyMatch.score(pattern: "Ab", in: "Ab") != nil)
    }

    @Test func consecutive_characters_outrank_a_gapped_match() throws {
        let tight = try #require(FuzzyMatch.score(pattern: "ab", in: "ab"))
        let gapped = try #require(FuzzyMatch.score(pattern: "ab", in: "axb"))
        let stretched = try #require(FuzzyMatch.score(pattern: "ab", in: "axxxb"))

        #expect(tight > gapped)
        #expect(gapped > stretched)
    }

    @Test func word_starts_outrank_hits_buried_in_a_word() throws {
        let spaced = try #require(FuzzyMatch.score(pattern: "fb", in: "foo bar"))
        let camel = try #require(FuzzyMatch.score(pattern: "fb", in: "fooBar"))
        let buried = try #require(FuzzyMatch.score(pattern: "fb", in: "xfoobar"))

        #expect(spaced > buried)
        #expect(camel > buried)
    }

    @Test func a_match_tells_where_each_pattern_character_landed() throws {
        let scattered = try #require(FuzzyMatch.match(pattern: "ab", in: "xaxxb"))
        let tight = try #require(FuzzyMatch.match(pattern: "ab", in: "a....ab"))

        #expect(scattered.positions == [1, 4])
        #expect(tight.positions == [5, 6])
        #expect(FuzzyMatch.match(pattern: "", in: "anything")?.positions == [])
        #expect(FuzzyMatch.match(pattern: "z", in: "anything") == nil)
    }

    @Test func a_two_byte_line_break_counts_as_one_character() {
        #expect(FuzzyMatch.match(pattern: "b", in: "a\r\nb")?.positions == [2])
        #expect(FuzzyMatch.match(pattern: "ab", in: "a\r\nb")?.positions == [0, 2])
    }

    @Test func an_accent_makes_another_character_even_right_after_the_last_hit() {
        #expect(FuzzyMatch.match(pattern: "e", in: "cafe\u{301}") == nil)
        #expect(FuzzyMatch.match(pattern: "e", in: "e\u{301} e")?.positions == [2])
        #expect(FuzzyMatch.match(pattern: "é", in: "café")?.positions == [3])
        #expect(FuzzyMatch.match(pattern: "é", in: "cafe") == nil)
        #expect(FuzzyMatch.match(pattern: "caf", in: "CAFÉ au lait")?.positions == [0, 1, 2])
    }

    @Test func plain_and_accented_candidates_score_alike() {
        let candidates = ["foo bar", "fooBar", "a....ab", "Hello_World", "x1 y2", "path/to/File.swift", "AB ab"]
        let patterns = ["fb", "ab", "hw", "HW", "y2", "ow", "ptf", "File", "B"]
        for candidate in candidates {
            for pattern in patterns {
                let plain = FuzzyMatch.match(pattern: pattern, in: candidate)
                let accented = FuzzyMatch.match(pattern: pattern, in: candidate + " é")
                #expect(plain == accented, "\(pattern) in \(candidate)")
            }
        }
    }

    @Test func signs_that_equal_a_plain_character_match_as_that_character() {
        #expect(FuzzyMatch.match(pattern: "k", in: "é 300 \u{212A}")?.positions == [6])
        #expect(FuzzyMatch.match(pattern: "K", in: "é 300 \u{212A}")?.positions == [6])
        #expect(FuzzyMatch.match(pattern: ";", in: "é\u{37E}")?.positions == [1])
        #expect(FuzzyMatch.match(pattern: "`", in: "é\u{1FEF}")?.positions == [1])
    }

    @Test func accented_text_matches_on_its_plain_and_accented_characters_alike() {
        #expect(FuzzyMatch.match(pattern: "xyz", in: "café au lait") == nil)
        #expect(FuzzyMatch.match(pattern: "lait", in: "Café au LAIT")?.positions == [8, 9, 10, 11])
        #expect(FuzzyMatch.match(pattern: "ét", in: "L'été")?.positions == [2, 3])
        #expect(FuzzyMatch.match(pattern: "éa", in: "L'été") == nil)
        #expect(FuzzyMatch.match(pattern: "Lait", in: "café au lait") == nil)
    }

    @Test func the_tightest_window_is_scored_not_the_earliest_start() throws {
        let tight = try #require(FuzzyMatch.score(pattern: "ab", in: "ab"))
        let late = try #require(FuzzyMatch.score(pattern: "ab", in: "a....ab"))

        #expect(late == tight)
    }
}
