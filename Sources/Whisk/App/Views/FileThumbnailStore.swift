import AppKit
import QuickLookThumbnailing
import SwiftUI

/// QuickLook thumbnails for copied files, cached by path. Views fall back
/// to the file-type icon until (or unless) a thumbnail arrives.
@MainActor
final class FileThumbnailStore: ObservableObject {
    static let shared = FileThumbnailStore()

    @Published private(set) var thumbnails: [String: NSImage] = [:]
    private var inFlight: Set<String> = []

    func thumbnail(for path: String) -> NSImage? {
        thumbnails[path]
    }

    func load(_ path: String) {
        guard thumbnails[path] == nil, !inFlight.contains(path) else { return }
        inFlight.insert(path)
        let request = QLThumbnailGenerator.Request(
            fileAt: URL(fileURLWithPath: path),
            size: CGSize(width: 202, height: 96),
            scale: 2,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            guard let cgImage = representation?.cgImage else { return }
            let image = NSImage(cgImage: cgImage, size: .zero)
            DispatchQueue.main.async {
                FileThumbnailStore.shared.thumbnails[path] = image
            }
        }
    }
}
