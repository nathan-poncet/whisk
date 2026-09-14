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

    @Test func the_tightest_window_is_scored_not_the_earliest_start() throws {
        let tight = try #require(FuzzyMatch.score(pattern: "ab", in: "ab"))
        let late = try #require(FuzzyMatch.score(pattern: "ab", in: "a....ab"))

        #expect(late == tight)
    }
}
