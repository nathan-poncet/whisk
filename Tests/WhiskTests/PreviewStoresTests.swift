import AppKit
import Combine
import LinkPresentation
import Testing

@testable import Whisk

/// Waits for a published value to satisfy a condition, bounded so a
/// callback that never comes fails the test instead of hanging it.
@MainActor
private func waitUntil<P: Publisher>(_ publisher: P, _ condition: @escaping (P.Output) -> Bool) async -> Bool
where P.Failure == Never {
    await withTaskGroup(of: Bool.self) { group in
        group.addTask { @MainActor in
            for await value in publisher.values where condition(value) {
                return true
            }
            return false
        }
        group.addTask {
            try? await Task.sleep(for: .seconds(5))
            return false
        }
        let first = await group.next() ?? false
        group.cancelAll()
        return first
    }
}

@MainActor
@Suite struct LinkPreviewAssembly {
    @Test func no_metadata_assembles_an_empty_preview_at_once() {
        var assembled: LinkPreview?

        LinkPreviewStore.assemble(metadata: nil, host: "example.com") { assembled = $0 }

        #expect(assembled?.host == "example.com")
        #expect(assembled?.hasContent == false)
    }

    @Test func metadata_with_a_title_and_an_icon_assembles_both() async {
        let metadata = LPLinkMetadata()
        metadata.title = "Whisk"
        metadata.iconProvider = NSItemProvider(object: ViewFixtures.swatch)

        let assembled: LinkPreview? = await withCheckedContinuation { continuation in
            LinkPreviewStore.assemble(metadata: metadata, host: "example.com") { continuation.resume(returning: $0) }
        }

        #expect(assembled?.title == "Whisk")
        #expect(assembled?.icon != nil)
        #expect(assembled?.image == nil)
    }

    @Test func a_provider_that_cannot_yield_an_image_yields_nil() async {
        let text = NSItemProvider(object: "just text" as NSString)

        let fromText: NSImage? = await withCheckedContinuation { continuation in
            LinkPreviewStore.loadImage(from: text) { continuation.resume(returning: $0) }
        }
        let fromNothing: NSImage? = await withCheckedContinuation { continuation in
            LinkPreviewStore.loadImage(from: nil) { continuation.resume(returning: $0) }
        }

        #expect(fromText == nil)
        #expect(fromNothing == nil)
    }

    @Test func loading_a_local_address_settles_on_a_preview_and_is_fetched_once() async {
        let store = LinkPreviewStore.shared
        let address = "file:///nonexistent/whisk/\(UUID().uuidString)"
        store.load("not a url")
        #expect(store.preview(for: "not a url") == nil)

        store.load(address)
        store.load(address)
        let settled = await waitUntil(store.$previews) { $0[address] != nil }

        #expect(settled)
        #expect(store.preview(for: address) != nil)
    }
}

@MainActor
@Suite struct FileThumbnailGeneration {
    @Test func a_real_file_gets_a_thumbnail_and_is_generated_once() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisk-thumbnails-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("note.txt")
        try Data("A plain text file, thumbnailed by QuickLook.".utf8).write(to: file)
        let store = FileThumbnailStore.shared
        #expect(store.thumbnail(for: file.path) == nil)

        store.load(file.path)
        store.load(file.path)
        let settled = await waitUntil(store.$thumbnails) { $0[file.path] != nil }

        #expect(settled)
        #expect(store.thumbnail(for: file.path) != nil)
    }
}
