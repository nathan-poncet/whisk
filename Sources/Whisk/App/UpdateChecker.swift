import Foundation

/// Checks the GitHub releases feed for a newer version. One anonymous
/// request at launch, nothing sent beyond it; DMG users get a menu entry,
/// Homebrew users already have `brew upgrade`.
final class UpdateChecker: ObservableObject {
    @Published private(set) var availableVersion: String?

    /// Why a check yielded no version. Logged rather than swallowed: a
    /// rate-limited 403 would otherwise read exactly like "up to date".
    enum Failure: Error, Equatable {
        case transport(String)
        case rejected(status: Int)
        case malformed
    }

    static let releasesPage = URL(string: "https://github.com/nathan-poncet/whisk/releases/latest")

    private static let latestAPI = URL(
        string: "https://api.github.com/repos/nathan-poncet/whisk/releases/latest")

    private let logger: any Logger

    init(logger: any Logger = ConsoleLogger()) {
        self.logger = logger
    }

    func checkNow() {
        guard let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let url = Self.latestAPI
        else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            switch Self.latestVersion(data: data, response: response, error: error) {
            case .failure(let failure):
                self?.logger.log("update check failed — \(failure)")
            case .success(let latest):
                guard Self.isNewer(latest, than: current) else { return }
                DispatchQueue.main.async {
                    self?.availableVersion = latest
                }
            }
        }.resume()
    }

    /// The latest published version in the releases API reply, or why
    /// there is none.
    static func latestVersion(data: Data?, response: URLResponse?, error: Error?) -> Result<String, Failure> {
        if let error {
            return .failure(.transport(error.localizedDescription))
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return .failure(.rejected(status: http.statusCode))
        }
        guard let data,
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tag = payload["tag_name"] as? String
        else { return .failure(.malformed) }
        return .success(tag.hasPrefix("v") ? String(tag.dropFirst()) : tag)
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let lhs = candidate.split(separator: ".").compactMap { Int($0) }
        let rhs = current.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right {
                return left > right
            }
        }
        return false
    }
}
