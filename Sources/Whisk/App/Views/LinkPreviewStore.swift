import AppKit
import LinkPresentation
import SwiftUI

/// Page metadata for a copied link — title, icon, lead image.
struct LinkPreview {
    let title: String?
    let host: String?
    let icon: NSImage?
    let image: NSImage?

    var hasContent: Bool {
        title != nil || icon != nil || image != nil
    }
}

/// Fetches and caches link metadata through LinkPresentation. Frameworks
/// ring: it touches the network, so nothing below the views knows about it.
/// Failures are cached too, so a dead link is only fetched once.
@MainActor
final class LinkPreviewStore: ObservableObject {
    static let shared = LinkPreviewStore()

    @Published private(set) var previews: [String: LinkPreview] = [:]
    private var inFlight: Set<String> = []

    func preview(for address: String) -> LinkPreview? {
        previews[address]
    }

    func load(_ address: String) {
        guard previews[address] == nil, !inFlight.contains(address),
            let url = URL(string: address)
        else { return }
        inFlight.insert(address)
        let provider = LPMetadataProvider()
        provider.timeout = 6
        provider.startFetchingMetadata(for: url) { metadata, _ in
            Self.assemble(metadata: metadata, host: url.host) { preview in
                DispatchQueue.main.async {
                    LinkPreviewStore.shared.previews[address] = preview
                }
            }
        }
    }

    private nonisolated static func assemble(
        metadata: LPLinkMetadata?,
        host: String?,
        completion: @escaping (LinkPreview) -> Void
    ) {
        guard let metadata else {
            completion(LinkPreview(title: nil, host: host, icon: nil, image: nil))
            return
        }
        let group = DispatchGroup()
        var icon: NSImage?
        var image: NSImage?
        group.enter()
        loadImage(from: metadata.iconProvider) {
            icon = $0
            group.leave()
        }
        group.enter()
        loadImage(from: metadata.imageProvider) {
            image = $0
            group.leave()
        }
        group.notify(queue: .main) {
            completion(LinkPreview(title: metadata.title, host: host, icon: icon, image: image))
        }
    }

    private nonisolated static func loadImage(from provider: NSItemProvider?, completion: @escaping (NSImage?) -> Void)
    {
        guard let provider, provider.canLoadObject(ofClass: NSImage.self) else {
            completion(nil)
            return
        }
        _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
            completion(object as? NSImage)
        }
    }
}
