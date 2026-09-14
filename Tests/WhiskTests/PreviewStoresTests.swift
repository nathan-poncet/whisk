import AppKit
import LinkPresentation
import Testing

@testable import Whisk

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

    // What the loader itself does — LinkPresentation on a real address —
    // stays out of the suite: the service does not answer on CI runners.
    @Test func loading_skips_bad_addresses_and_previews_already_held() {
        let store = LinkPreviewStore()
        let address = "https://example.com/held"
        store.store(LinkPreview(title: "Held", host: "example.com", icon: nil, image: nil), for: address)

        store.load("not a url")
        store.load(address)

        #expect(store.preview(for: "not a url") == nil)
        #expect(store.preview(for: address)?.title == "Held")
    }
}

@MainActor
@Suite struct LinkPreviewOptOut {
    @Test func switched_off_the_store_neither_fetches_nor_shows_what_it_already_holds() {
        let store = LinkPreviewStore()
        let address = "https://example.com/private"
        store.store(LinkPreview(title: "Private", host: "example.com", icon: nil, image: nil), for: address)
        #expect(store.preview(for: address) != nil)

        store.setEnabled(false)
        store.load("https://example.com/another")

        #expect(!store.isEnabled)
        #expect(store.preview(for: address) == nil)
        #expect(store.previews["https://example.com/another"] == nil)

        store.setEnabled(true)
        #expect(store.preview(for: address)?.title == "Private")
    }
}

@MainActor
@Suite struct PreviewCacheBounds {
    @Test func the_link_and_thumbnail_caches_let_everything_go_past_their_limit() {
        // Instances of their own: the shared ones serve other suites
        // concurrently.
        let links = LinkPreviewStore()
        let files = FileThumbnailStore()
        let empty = LinkPreview(title: nil, host: nil, icon: nil, image: nil)

        for index in 0..<(LinkPreviewStore.limit + 1) {
            links.store(empty, for: "https://example.com/bound/\(index)")
        }
        for index in 0..<(FileThumbnailStore.limit + 1) {
            files.store(ViewFixtures.swatch, for: "/nonexistent/bound/\(index)")
        }

        #expect(links.previews.count <= LinkPreviewStore.limit)
        #expect(files.thumbnails.count <= FileThumbnailStore.limit)
        #expect(links.preview(for: "https://example.com/bound/\(LinkPreviewStore.limit)") != nil)
    }
}

@MainActor
@Suite struct FileThumbnailStorage {
    // Generating a thumbnail — QuickLook on a real file — stays out of the
    // suite: the service does not answer on CI runners.
    @Test func a_thumbnail_already_held_is_neither_regenerated_nor_lost() {
        let store = FileThumbnailStore()
        let path = "/nonexistent/whisk/held.txt"
        let held = ViewFixtures.swatch
        #expect(store.thumbnail(for: path) == nil)

        store.store(held, for: path)
        store.load(path)

        #expect(store.thumbnail(for: path) === held)
    }
}
