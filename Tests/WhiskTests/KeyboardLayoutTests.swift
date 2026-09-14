import Testing

@testable import Whisk

/// Resolved against whatever layout the test host runs under: the two
/// directions must agree with each other for every letter.
@MainActor
@Suite struct KeyboardLayoutResolution {
    @Test func every_letter_and_its_key_code_round_trip() throws {
        for character in "abcdefghijklmnopqrstuvwxyz" {
            let keyCode = try #require(KeyboardLayout.keyCode(for: character), "no key prints \(character)")
            #expect(KeyboardLayout.character(for: UInt16(keyCode)) == character)
        }
    }

    @Test func resolution_ignores_the_case_asked_for() {
        #expect(KeyboardLayout.keyCode(for: "V") == KeyboardLayout.keyCode(for: "v"))
    }
}
