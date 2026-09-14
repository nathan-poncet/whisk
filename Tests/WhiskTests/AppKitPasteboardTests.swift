import AppKit
import Testing

@testable import Whisk

/// The gateway over a private pasteboard of its own, released when the
/// test ends — the general pasteboard is never touched.
@MainActor
@Suite struct AppKitPasteboardCapture {
    private final class PrivateBoard {
        let board: NSPasteboard

        init() {
            board = NSPasteboard(name: NSPasteboard.Name("whisk-tests-\(UUID().uuidString)"))
        }

        deinit {
            board.releaseGlobally()
        }
    }

    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    @Test func an_unchanged_pasteboard_yields_nothing() {
        let sandbox = PrivateBoard()
        let gateway = AppKitPasteboard(board: sandbox.board)

        #expect(gateway.readIfChanged() == nil)
    }

    @Test func a_string_is_captured_once_per_change() {
        let sandbox = PrivateBoard()
        let gateway = AppKitPasteboard(board: sandbox.board)
        sandbox.board.clearContents()
        sandbox.board.setString("hello", forType: .string)

        #expect(gateway.readIfChanged()?.payload == .text("hello"))
        #expect(gateway.readIfChanged() == nil)
    }

    @Test func a_bare_web_address_becomes_a_link_but_prose_around_one_stays_text() throws {
        let sandbox = PrivateBoard()
        let gateway = AppKitPasteboard(board: sandbox.board)
        let url = try #require(URL(string: "https://example.com/path"))

        sandbox.board.clearContents()
        sandbox.board.setString(" https://example.com/path\n", forType: .string)
        #expect(gateway.readIfChanged()?.payload == .link(url))

        sandbox.board.clearContents()
        sandbox.board.setString("see https://example.com/path please", forType: .string)
        #expect(gateway.readIfChanged()?.payload == .text("see https://example.com/path please"))
    }

    @Test func concealed_content_is_never_captured() {
        let sandbox = PrivateBoard()
        let gateway = AppKitPasteboard(board: sandbox.board)
        sandbox.board.declareTypes([.string, Self.concealed], owner: nil)
        sandbox.board.setString("hunter2", forType: .string)
        sandbox.board.setString("", forType: Self.concealed)

        #expect(gateway.readIfChanged() == nil)
    }

    @Test func rich_text_travels_beside_the_plain_text() {
        let sandbox = PrivateBoard()
        let gateway = AppKitPasteboard(board: sandbox.board)
        let rtf = Data("{\\rtf1 hello}".utf8)
        sandbox.board.declareTypes([.string, .rtf], owner: nil)
        sandbox.board.setString("hello", forType: .string)
        sandbox.board.setData(rtf, forType: .rtf)

        let snapshot = gateway.readIfChanged()

        #expect(snapshot?.payload == .text("hello"))
        #expect(snapshot?.rtf == rtf)
    }

    @Test func file_urls_win_over_everything_else() {
        let sandbox = PrivateBoard()
        let gateway = AppKitPasteboard(board: sandbox.board)
        sandbox.board.clearContents()
        sandbox.board.writeObjects([NSURL(fileURLWithPath: "/tmp/a.txt"), NSURL(fileURLWithPath: "/tmp/b.txt")])

        #expect(gateway.readIfChanged()?.payload == .fileReferences(["/tmp/a.txt", "/tmp/b.txt"]))
    }

    @Test func png_is_captured_as_is_and_tiff_is_normalized_to_png() throws {
        let sandbox = PrivateBoard()
        let gateway = AppKitPasteboard(board: sandbox.board)
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        let tiff = try #require(bitmap.tiffRepresentation)

        sandbox.board.clearContents()
        sandbox.board.setData(png, forType: .png)
        #expect(gateway.readIfChanged()?.payload == .image(png))

        sandbox.board.clearContents()
        sandbox.board.setData(tiff, forType: .tiff)
        guard case .image(let normalized)? = gateway.readIfChanged()?.payload else {
            Issue.record("expected an image")
            return
        }
        #expect(normalized.prefix(4) == Data([0x89, 0x50, 0x4E, 0x47]))
    }

    @Test func own_writes_are_not_captured_again() {
        let sandbox = PrivateBoard()
        let gateway = AppKitPasteboard(board: sandbox.board)

        gateway.write(.text("from whisk"), rtf: nil)

        #expect(sandbox.board.string(forType: .string) == "from whisk")
        #expect(gateway.readIfChanged() == nil)
    }

    @Test func writing_puts_each_payload_kind_on_the_board() throws {
        let sandbox = PrivateBoard()
        let gateway = AppKitPasteboard(board: sandbox.board)
        let url = try #require(URL(string: "https://example.com"))
        let rtf = Data("{\\rtf1 hi}".utf8)

        gateway.write(.text("hi"), rtf: rtf)
        #expect(sandbox.board.string(forType: .string) == "hi")
        #expect(sandbox.board.data(forType: .rtf) == rtf)

        gateway.write(.link(url), rtf: nil)
        #expect(sandbox.board.string(forType: .string) == "https://example.com")
        #expect(sandbox.board.data(forType: .rtf) == nil)

        gateway.write(.image(Data([0x89, 0x50])), rtf: nil)
        #expect(sandbox.board.data(forType: .png) == Data([0x89, 0x50]))

        gateway.write(.fileReferences(["/tmp/a.txt"]), rtf: nil)
        let urls =
            sandbox.board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        #expect(urls?.map(\.path) == ["/tmp/a.txt"])
    }
}
