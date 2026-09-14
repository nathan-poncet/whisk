import Foundation
import Testing
@testable import Whisk

@Suite struct UseCaseBehaviour {
    let pasteboard = ScriptedPasteboard()
    let clock = FakeClock()
    let store = InMemoryHistoryStore()

    @Test func capture_records_a_change_and_persists_it() throws {
        pasteboard.pendingSnapshots = [PasteboardSnapshot(payload: .text("copied"), source: SourceApp(name: "Safari"))]
        let capture = CaptureClipboardChange(pasteboard: pasteboard, clock: clock, store: store)

        let history = try capture(into: History())

        #expect(history.items.map(\.payload) == [.text("copied")])
        #expect(history.items[0].source?.name == "Safari")
        #expect(store.stored == history.items)
    }

    @Test func capture_does_nothing_while_the_pasteboard_is_unchanged() throws {
        let capture = CaptureClipboardChange(pasteboard: pasteboard, clock: clock, store: store)

        let history = try capture(into: History())

        #expect(history.items.isEmpty)
        #expect(store.saveCount == 0)
    }

    @Test func selecting_writes_the_payload_back_and_moves_the_item_to_front() throws {
        var history = History()
            .recording(.text("wanted"), from: nil, at: clock.now())
        let wanted = history.items[0]
        clock.advance(by: 60)
        history = history.recording(.text("newer"), from: nil, at: clock.now())
        let select = SelectItem(pasteboard: pasteboard, clock: clock, store: store)

        let next = try select(wanted.id, in: history)

        #expect(pasteboard.written == [.text("wanted")])
        #expect(next.items[0].id == wanted.id)
        #expect(store.stored == next.items)
    }

    @Test func selecting_an_unknown_id_leaves_history_untouched() throws {
        let history = History().recording(.text("only"), from: nil, at: clock.now())
        let select = SelectItem(pasteboard: pasteboard, clock: clock, store: store)

        let next = try select(UUID(), in: history)

        #expect(next == history)
        #expect(pasteboard.written.isEmpty)
        #expect(store.saveCount == 0)
    }

    @Test func load_rebuilds_history_from_the_store_and_enforces_capacity() throws {
        store.stored = [
            anItem(.text("newest")),
            anItem(.text("middle")),
            anItem(.text("oldest")),
        ]
        let capacity = try #require(HistoryCapacity(2))
        let load = LoadHistory(store: store, capacity: capacity)

        let history = try load()

        #expect(history.items.map(\.payload) == [.text("newest"), .text("middle")])
    }

    @Test func toggling_delete_and_clear_persist_their_result() throws {
        var history = History()
            .recording(.text("pin me"), from: nil, at: clock.now())
            .recording(.text("ephemeral"), from: nil, at: clock.now())
        let pinTarget = history.items[1].id
        let togglePin = TogglePin(store: store)
        let clear = ClearHistory(store: store)
        let delete = DeleteItem(store: store)

        history = try togglePin(pinTarget, in: history)
        history = try clear(history)
        #expect(history.items.map(\.payload) == [.text("pin me")])

        history = try delete(pinTarget, in: history)
        #expect(history.items.isEmpty)
        #expect(store.stored.isEmpty)
        #expect(store.saveCount == 3)
    }
}

@Suite struct RichTextBehaviour {
    let pasteboard = ScriptedPasteboard()
    let clock = FakeClock()
    let store = InMemoryHistoryStore()

    @Test func capture_keeps_the_rich_bytes_and_selection_writes_them_back() throws {
        let rtf = Data("rich".utf8)
        pasteboard.pendingSnapshots = [PasteboardSnapshot(payload: .text("hello"), source: nil, rtf: rtf)]
        let capture = CaptureClipboardChange(pasteboard: pasteboard, clock: clock, store: store)
        let select = SelectItem(pasteboard: pasteboard, clock: clock, store: store)

        let history = try capture(into: History())
        #expect(history.items[0].rtf == rtf)

        _ = try select(history.items[0].id, in: history)
        #expect(pasteboard.writtenRTF == [rtf])

        _ = try select(history.items[0].id, in: history, plain: true)
        #expect(pasteboard.writtenRTF == [rtf, nil])
    }
}

@Suite struct TextTransforming {
    @Test func case_and_whitespace_transforms_rewrite_as_named() {
        #expect(TextTransform.uppercase.apply(to: "héllo World") == "HÉLLO WORLD")
        #expect(TextTransform.lowercase.apply(to: "HÉLLO World") == "héllo world")
        #expect(TextTransform.trimmed.apply(to: "  padded \n") == "padded")
        #expect(TextTransform.singleLine.apply(to: "one\n  two  \n\nthree") == "one two three")
        #expect(TextTransform.withoutAccents.apply(to: "Élève à Zürich") == "Eleve a Zurich")
    }

    @Test func url_and_base64_transforms_round_trip_and_refuse_what_they_cannot_read() {
        #expect(TextTransform.urlEncoded.apply(to: "a b&c=d/é") == "a%20b%26c%3Dd%2F%C3%A9")
        #expect(TextTransform.urlDecoded.apply(to: "a%20b%26c") == "a b&c")
        #expect(TextTransform.base64Encoded.apply(to: "hello") == "aGVsbG8=")
        #expect(TextTransform.base64Decoded.apply(to: " aGVsbG8= ") == "hello")
        #expect(TextTransform.base64Decoded.apply(to: "not base64!") == nil)
    }

    @Test func json_is_formatted_with_sorted_keys_and_anything_else_is_refused() {
        let formatted = TextTransform.prettyJSON.apply(to: #"{"b":1,"a":["x","y/z"]}"#)

        #expect(formatted == "{\n  \"a\" : [\n    \"x\",\n    \"y/z\"\n  ],\n  \"b\" : 1\n}")
        #expect(TextTransform.prettyJSON.apply(to: "not json") == nil)
    }

    @Test func text_and_links_can_be_transformed_images_and_files_cannot() throws {
        let url = try #require(URL(string: "https://example.com/a b"))

        #expect(Payload.text("hi").transformableText == "hi")
        #expect(Payload.link(url).transformableText == url.absoluteString)
        #expect(Payload.image(Data([0x01])).transformableText == nil)
        #expect(Payload.fileReferences(["/tmp/a"]).transformableText == nil)
    }

    @Test func selecting_with_a_replacement_writes_it_plain_and_still_refreshes_the_item() throws {
        let pasteboard = ScriptedPasteboard()
        let clock = FakeClock()
        let store = InMemoryHistoryStore()
        var history = History().recording(.text("Hello"), from: nil, rtf: Data("rich".utf8), at: clock.now())
        let item = history.items[0]
        clock.advance(by: 60)
        history = history.recording(.text("newer"), from: nil, at: clock.now())
        let select = SelectItem(pasteboard: pasteboard, clock: clock, store: store)

        let next = try select(item.id, in: history, writing: .text("HELLO"))

        #expect(pasteboard.written == [.text("HELLO")])
        #expect(pasteboard.writtenRTF == [nil])
        #expect(next.items[0].id == item.id)
        #expect(next.items[0].payload == .text("Hello"))
    }
}
