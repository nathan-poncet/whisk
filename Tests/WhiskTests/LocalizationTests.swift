import Foundation
import Testing

@testable import Whisk

/// The catalogs and the code that reads them, checked against each other:
/// every key the code asks for exists in both languages, and no key
/// lingers unused.
@Suite struct LocalizationCatalogs {
    private static let languages = ["en", "fr"]

    private func catalog(_ language: String) throws -> [String: Any] {
        var merged: [String: Any] = [:]
        for ext in ["strings", "stringsdict"] {
            let url = try #require(
                Bundle.module.url(
                    forResource: "Localizable", withExtension: ext, subdirectory: nil, localization: language))
            let dictionary = try #require(NSDictionary(contentsOf: url) as? [String: Any])
            merged.merge(dictionary) { current, _ in current }
        }
        return merged
    }

    /// Every key the sources ask for, each as the set of catalog keys it
    /// may resolve to: `"\(count) items"` reaches the catalog as
    /// `%lld items`, an object interpolation as `%@`.
    private func keysUsedInSources() throws -> [Set<String>] {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let sources = root.appendingPathComponent("Sources/Whisk", isDirectory: true)
        let enumerator = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        let call = try NSRegularExpression(pattern: #"localized\(\s*"((?:[^"\\]|\\.)*)"\s*\)"#)
        let interpolation = try NSRegularExpression(pattern: #"\\\([^)]*\)"#)
        var used: [Set<String>] = []
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let text = try String(contentsOf: file, encoding: .utf8)
            for match in call.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range(at: 1), in: text) else { continue }
                let literal = String(text[range]).replacingOccurrences(of: "\\\"", with: "\"")
                let whole = NSRange(literal.startIndex..., in: literal)
                used.append([
                    interpolation.stringByReplacingMatches(in: literal, range: whole, withTemplate: "%lld"),
                    interpolation.stringByReplacingMatches(in: literal, range: whole, withTemplate: "%@"),
                ])
            }
        }
        return used
    }

    @Test func english_and_french_carry_the_same_keys() throws {
        let english = Set(try catalog("en").keys)
        let french = Set(try catalog("fr").keys)

        #expect(english.subtracting(french).isEmpty)
        #expect(french.subtracting(english).isEmpty)
    }

    @Test func every_key_the_code_asks_for_exists() throws {
        let english = Set(try catalog("en").keys)

        let missing = try keysUsedInSources().filter { $0.isDisjoint(with: english) }

        #expect(missing.isEmpty, "keys without a catalog entry: \(missing)")
    }

    @Test func no_catalog_key_lingers_unused() throws {
        let english = Set(try catalog("en").keys)
        let used = try keysUsedInSources().reduce(into: Set<String>()) { $0.formUnion($1) }

        let unused = english.subtracting(used)

        #expect(unused.isEmpty, "catalog keys no code asks for: \(unused.sorted())")
    }

    @Test func strings_resolve_through_the_module_catalogs() throws {
        let english = try #require(try catalog("en")["Forever"] as? String)
        let french = try #require(try catalog("fr")["Forever"] as? String)

        #expect([english, french].contains(localized("Forever")))
    }

    @Test func plural_forms_follow_the_count() {
        #expect(["1 item", "1 élément"].contains(localized("\(1) items")))
        #expect(["2 items", "2 éléments"].contains(localized("\(2) items")))
        #expect(["1 character", "1 caractère"].contains(localized("\(1) characters")))
        #expect(["40 characters", "40 caractères"].contains(localized("\(40) characters")))
    }
}
