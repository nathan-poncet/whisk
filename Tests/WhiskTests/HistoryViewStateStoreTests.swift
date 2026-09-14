import Foundation
import Testing

@testable import Whisk

@MainActor
@Suite struct PanelInputModes {
    @Test func with_vim_off_the_field_always_has_focus_and_never_the_cursor() {
        let store = HistoryViewStateStore()

        store.configureInput(vim: false, searchKey: "s")

        #expect(store.searchActive)
        #expect(!store.cursorOnSearch)
        #expect(!store.searchExpanded(typed: ""))
        #expect(store.searchExpanded(typed: "a"))
    }

    @Test func vim_opens_in_normal_mode_and_search_mode_takes_the_cursor() {
        let store = HistoryViewStateStore()

        store.configureInput(vim: true, searchKey: "/")

        #expect(store.vimEnabled)
        #expect(!store.searchActive)
        #expect(store.vimSearchKey == "/")
        #expect(!store.cursorOnSearch)
        #expect(!store.searchExpanded(typed: ""))

        store.setSearchActive(true)
        #expect(store.cursorOnSearch)
        #expect(store.searchExpanded(typed: ""))

        store.setSearchActive(true)
        store.setSearchActive(false)
        #expect(!store.cursorOnSearch)
    }

    @Test func focus_and_close_requests_bump_their_revisions() {
        let store = HistoryViewStateStore()

        store.requestSearchFocus()
        store.requestSearchFocus()
        store.panelDidClose()

        #expect(store.focusRevision == 2)
        #expect(store.closeRevision == 1)
    }

    @Test func the_card_side_drives_the_zoomed_slot_and_the_rail_stride() {
        let store = HistoryViewStateStore()
        #expect(store.cardSide == 200)
        #expect(store.cardStride == 224)

        store.configureCards(side: 160)

        #expect(store.zoomedCardSide == 168)
        #expect(store.cardStride == 182)
        #expect(PanelController.panelHeight(forCardSide: 200) == 430)
        #expect(PanelController.panelHeight(forCardSide: 250) == 480)
    }

    @Test func the_presented_state_is_what_the_views_read() {
        let store = HistoryViewStateStore()
        #expect(store.state == .empty)
        let presented = HistoryPresenter().present(
            items: [anItem(.text("a"))], query: "q", now: Date(timeIntervalSince1970: 1_700_000_000))

        store.update(presented)

        #expect(store.state == presented)
    }
}
