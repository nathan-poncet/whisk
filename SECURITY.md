# Security policy

Whisk reads everything that lands on the clipboard and keeps it on disk.
A flaw in how it captures, stores or previews that content is worth a
quiet report, not a public issue.

## Supported versions

Only the latest release receives fixes. Homebrew users get them with
`brew upgrade`; DMG users through the update check at launch.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting:
**Security → Report a vulnerability** on
[github.com/nathan-poncet/whisk](https://github.com/nathan-poncet/whisk/security/advisories/new).
Nothing you write there is visible to anyone but the maintainer until a
fix is out.

Please include what you observed, how to reproduce it, and the Whisk and
macOS versions. You will get an acknowledgement within seven days, and
the fix ships in the next release with credit to you unless you prefer
otherwise.

## What counts

- Content marked concealed or transient by a password manager, or
  copied from an excluded application, ending up in the history.
- History, previews or the paste stack readable by another user account
  or leaving the machine other than through the two documented requests
  (link metadata for a copied URL, the release check on GitHub).
- A crafted clipboard payload that crashes the app or runs code.

## What does not

- Whisk asking for Accessibility access: it is needed to paste in place,
  optional, and documented at first launch.
- The history being readable by the same macOS user account that runs
  Whisk, in `~/Library/Application Support/Whisk`. That is where it lives;
  full-disk encryption is the protection for a lost machine.
- Gatekeeper refusing a build that is not an official release: only the
  releases on GitHub are signed with a Developer ID and notarized.
