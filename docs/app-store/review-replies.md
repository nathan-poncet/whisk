# Replies to App Review

Messages sent in App Store Connect in answer to review rejections, kept
so that a later submission can reuse the arguments. Newest first.

## 2026-09-25 — 1.0.0 (5), Guidelines 2.4.5 and 1.5

Rejection: the app "uses Accessibility features for automation purposes"
(2.4.5), and the Support URL pointed at the GitHub issue tracker (1.5).

```text
Hello,

Thank you for the review. Here is our answer on both points.

GUIDELINE 2.4.5 – ACCESSIBILITY

Whisk asks for Accessibility access for one purpose: when the user picks an item in Whisk's panel, the app sends a single Command-V keystroke to the application the user was working in, so the chosen item lands in the field they were typing in. That is the whole use. Whisk does not read, inspect or control the interface of any other application, does not observe keystrokes, and does nothing in the background on the user's behalf: each keystroke it sends is the direct result of the user pressing Return or clicking a card at that moment. The global shortcut that opens the panel is registered with Carbon's RegisterEventHotKey, which needs no permission at all.

The permission is optional and the app is complete without it. Whisk does not ask for it at launch: the first-run screen explains what it is for and that it can be skipped, and the system prompt appears only the first time the user picks an item to paste. When access is not granted, the item is still copied to the clipboard and the user presses Command-V themselves. The user can withdraw the permission at any time and nothing else in the app changes. The App Store description, the review notes and the privacy policy all say so.

Technically, the app posts the keystroke with CGEvent, which macOS gates behind the "PostEvent" privilege. System Settings lists that privilege in the Accessibility pane, next to the separate privilege that governs the AXUIElement API, but Whisk uses no AXUIElement API and reads nothing from other applications. It is also the only sandbox-compatible way to do it: the AXUIElement API is not available to sandboxed apps, and posting the paste keystroke is how clipboard managers on the Mac App Store, such as Paste, Pastebot and Maccy, put the chosen item into the frontmost application. Without it, a clipboard manager cannot do the one thing users install it for.

We believe this is a minimal, user-initiated and fully disclosed use of the permission, and we ask you to reconsider. If App Review's position is that a sandboxed clipboard manager may not send the paste keystroke at all, please say so explicitly, and tell us which API you would consider appropriate for pasting the item the user selected.

GUIDELINE 1.5 – SUPPORT URL

The Support URL now points to a dedicated support page, https://nathan-poncet.github.io/whisk/support.html, with answers to the common questions and the ways to ask a question or report a problem. The metadata has been updated in App Store Connect.

Thank you,
Nathan Poncet
```
