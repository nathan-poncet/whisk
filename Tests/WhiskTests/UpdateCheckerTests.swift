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
