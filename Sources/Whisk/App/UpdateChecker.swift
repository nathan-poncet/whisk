import AppKit
import Foundation

/// Checks the GitHub releases feed for a newer version. One anonymous
/// request at launch, nothing sent beyond it; DMG users get a menu entry,
/// Homebrew users already have `brew upgrade`.
final class UpdateChecker: ObservableObject {
    @Published private(set) var availableVersion: String?

    static let releasesPage = URL(string: "https://github.com/nathan-poncet/whisk/releases/latest")

    private static let latestAPI = URL(
        string: "https://api.github.com/repos/nathan-poncet/whisk/releases/latest")

    func checkNow() {
        guard let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let url = Self.latestAPI
        else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data,
                let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tag = payload["tag_name"] as? String
            else { return }
            let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            guard Self.isNewer(latest, than: current) else { return }
            DispatchQueue.main.async {
                self?.availableVersion = latest
            }
        }.resume()
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
