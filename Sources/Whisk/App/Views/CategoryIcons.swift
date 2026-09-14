import AppKit

/// Bundled icons for category chips. The Neovim mark (the code chip) ships
/// in the SwiftPM resource bundle — logo by Jason Long, CC BY 3.0.
///
/// Resolved by hand rather than through `Bundle.module`: the generated
/// accessor traps when the bundle is missing, and a decorative icon must
/// never take the app down — chips fall back to an SF Symbol instead.
enum CategoryIcons {
    private static var cache: [String: NSImage?] = [:]

    /// The image shipped under this resource name, resolved once; nil when
    /// the bundle lacks it.
    static func image(named name: String) -> NSImage? {
        if let cached = cache[name] {
            return cached
        }
        let image = loadResource(name)
        cache[name] = image
        return image
    }

    private static func loadResource(_ name: String) -> NSImage? {
        let candidates = [
            Bundle.main.resourceURL,
            Bundle.main.bundleURL,
            Bundle.main.executableURL?.deletingLastPathComponent(),
        ]
        for candidate in candidates {
            guard let url = candidate?.appendingPathComponent("Whisk_Whisk.bundle"),
                let bundle = Bundle(url: url),
                let image = bundle.image(forResource: name)
            else { continue }
            return image
        }
        return nil
    }
}
