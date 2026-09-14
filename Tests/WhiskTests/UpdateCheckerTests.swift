import Foundation
import Testing

@testable import Whisk

@Suite struct UpdateCheckParsing {
    private func response(_ status: Int) throws -> HTTPURLResponse {
        let url = try #require(URL(string: "https://api.github.com/repos/nathan-poncet/whisk/releases/latest"))
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
    }

    @Test func a_release_tag_yields_its_version_without_the_v() throws {
        let tagged = Data(#"{"tag_name": "v0.9.1", "name": "0.9.1"}"#.utf8)
        let bare = Data(#"{"tag_name": "1.2.3"}"#.utf8)

        #expect(UpdateChecker.latestVersion(data: tagged, response: try response(200), error: nil) == .success("0.9.1"))
        #expect(UpdateChecker.latestVersion(data: bare, response: nil, error: nil) == .success("1.2.3"))
    }

    @Test func a_rate_limited_reply_is_a_failure_not_an_up_to_date() throws {
        let body = Data(#"{"message": "API rate limit exceeded"}"#.utf8)

        let outcome = UpdateChecker.latestVersion(data: body, response: try response(403), error: nil)

        #expect(outcome == .failure(.rejected(status: 403)))
    }

    @Test func a_transport_error_and_a_malformed_body_are_told_apart() throws {
        let offline = URLError(.notConnectedToInternet)

        #expect(
            UpdateChecker.latestVersion(data: nil, response: nil, error: offline)
                == .failure(.transport(offline.localizedDescription)))
        #expect(
            UpdateChecker.latestVersion(data: Data("<html>".utf8), response: try response(200), error: nil)
                == .failure(.malformed))
        #expect(UpdateChecker.latestVersion(data: nil, response: try response(200), error: nil) == .failure(.malformed))
    }
}

@MainActor
@Suite struct UpdateCheckFlow {
    private func reply(_ status: Int, _ body: String) -> UpdateChecker.Fetch {
        { url, completion in
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)
            completion(Data(body.utf8), response, nil)
        }
    }

    private func settle(_ checker: UpdateChecker) async {
        for _ in 0..<20 where checker.availableVersion == nil {
            await Task.yield()
        }
    }

    @Test func a_newer_release_becomes_available_after_the_check() async {
        let checker = UpdateChecker(
            currentVersion: "0.8.0", fetch: reply(200, #"{"tag_name": "v9.9.9"}"#), logger: RecordingLogger())

        checker.checkNow()
        await settle(checker)

        #expect(checker.availableVersion == "9.9.9")
    }

    @Test func an_older_or_equal_release_is_not_offered() async {
        let checker = UpdateChecker(
            currentVersion: "0.8.0", fetch: reply(200, #"{"tag_name": "v0.8.0"}"#), logger: RecordingLogger())

        checker.checkNow()
        await settle(checker)

        #expect(checker.availableVersion == nil)
    }

    @Test func a_failed_check_is_logged_and_offers_nothing() async {
        let logger = RecordingLogger()
        let checker = UpdateChecker(currentVersion: "0.8.0", fetch: reply(403, "{}"), logger: logger)

        checker.checkNow()
        await settle(checker)

        #expect(checker.availableVersion == nil)
        #expect(logger.messages == ["update check failed — rejected(status: 403)"])
    }

    @Test func without_a_version_of_its_own_nothing_is_fetched() {
        var fetched = 0
        let checker = UpdateChecker(currentVersion: nil, fetch: { _, _ in fetched += 1 }, logger: RecordingLogger())

        checker.checkNow()

        #expect(fetched == 0)
        #expect(UpdateChecker.releasesPage?.host == "github.com")
    }
}
