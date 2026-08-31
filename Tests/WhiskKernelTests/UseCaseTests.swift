import Foundation
import WhiskKernel
import Testing

@Suite struct UseCaseBehaviour {
    let pasteboard = ScriptedPasteboard()
    let clock = FakeClock()
    let store = InMemoryHistoryStore()

    @Test func capture_records_a_change_and_persists_it() throws {
        pasteboard.pendingSnapshots = [PasteboardSnapshot(payload: .text("copied"), sourceApp: "Safari")]
        let capture = CaptureClipboardChange(pasteboard: pasteboard, clock: clock, store: store)

        let history = try capture(into: History())

        #expect(history.items.map(\.payload) == [.text("copied")])
        #expect(history.items[0].sourceApp == "Safari")
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
