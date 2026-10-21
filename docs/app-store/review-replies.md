# Replies to App Review

Messages sent in App Store Connect in answer to review rejections, kept
so that a later submission can reuse the arguments. Newest first.

## 2026-10-21 — 1.0.2 (6), Guidelines 2.1(a) and 1.5

Rejection of 2026-10-13: "all buttons in the main dashboard were
unresponsive upon launch" on macOS 27.0 (2.1(a)), and the support page
"does not direct to a website with information users can use to ask
questions and request support" (1.5). Sent with the resubmission of
1.0.3.

```text
Hello,

Thank you for the review. A new build, 1.0.3, is submitted and the Support URL has been updated; here is what changed on each point.

GUIDELINE 2.1(a) – UNRESPONSIVE BUTTONS AT LAUNCH

We could not reproduce the problem on a Mac running macOS 27.0 (26A428), where the welcome window and the panel respond normally, but we identified the one path that blocks the app. On a Mac where macOS asks before an app reads the clipboard (Paste from Other Apps, under Privacy & Security), build 1.0.2 read the clipboard from its background poll, and that read raised the system alert synchronously on the main thread, as soon as anything was on the clipboard. The app then looked unresponsive until the alert was answered.

Build 1.0.3 never reads the clipboard until macOS reports the access as allowed. Where macOS would ask, the welcome window, the panel and the menu bar show an Allow Clipboard Access button; clicking it triggers the system alert once, and the app opens the Paste from Other Apps pane so the permission can be set to Allow for good. Capture starts the moment it is allowed, and nothing else in the app changes. We verified this flow on macOS 27.0 with Apple's pasteboard privacy enforcement enabled: launch, welcome window, panel, allow, capture.

If what you saw is different, we would be grateful for a screenshot or a short description of what was on screen, so that we can reproduce it.

GUIDELINE 1.5 – SUPPORT URL

The support page at https://nathan-poncet.github.io/whisk/support.html now gives a direct email address, nathan.poncet.pro@gmail.com, in addition to the issue tracker and the answers to the common questions. Users can ask a question or request support without creating an account.

Thank you,
Nathan Poncet
```

## 2026-10-01 — 1.0.0 (5), Guideline 2.4.5, second rejection

Rejection of 2026-09-29, after the first reply: the app "still uses
Accessibility features to enable paste function".

```text
Hello,

Thank you for taking the time to review Whisk again, and for describing the issue so clearly. We would respectfully like to ask you to reconsider, and to explain in more detail how the app uses the permission in question.

What the permission does in Whisk

Whisk requests Accessibility access for exactly one action. When the user picks an item in Whisk's panel, the app sends a single Command-V keystroke to the application the user was working in, so that the chosen item lands in the field they were typing in. Each keystroke is the immediate result of the user pressing Return or clicking a card. Whisk does not read, inspect or control the interface of any other application, does not observe the user's keystrokes, and does nothing in the background. The global shortcut that opens the panel is registered with Carbon's RegisterEventHotKey, which needs no permission at all.

The permission is optional and disclosed

The app is complete without it. Whisk never requests the permission at launch: the first-run screen explains what it is for and that it can be skipped, and the system prompt appears only the first time the user chooses to paste. Without the permission, the chosen item is copied to the clipboard and the user presses Command-V. The user can withdraw the permission at any time, and nothing else in the app changes. The App Store description, the review notes and the privacy policy all state this.

A note on the underlying mechanism

The keystroke is posted with CGEvent, which macOS gates behind the PostEvent privilege. System Settings lists that privilege in the Accessibility pane, next to the separate privilege that governs the AXUIElement API, but Whisk uses no AXUIElement API. For a sandboxed application, this is the only available way to paste an item into another application.

Consistency with the Mac App Store

Pasting the selected item into the frontmost application through this permission is the established behaviour of clipboard managers currently distributed on the Mac App Store, among them Paste, Pastebot, Maccy, PastePal and Pasta. Whisk does nothing more than these apps do. We were unable to find a published rule that would distinguish Whisk from them, and we believe users of the Mac App Store expect a clipboard manager to paste.

Our request

We kindly ask you to reconsider the decision. If App Review's position is that a sandboxed clipboard manager may not send a paste keystroke, we would be grateful if you could say so explicitly and tell us which API you would consider appropriate for this purpose. As you suggested, we are also submitting an enhancement request through Feedback Assistant for a dedicated API.

Thank you for your time; we remain available for any question.

Kind regards,
Nathan Poncet
```

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
