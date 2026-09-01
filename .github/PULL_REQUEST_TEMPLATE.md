## What & why

<!-- What this PR changes and the problem it solves. Link the issue if there is one. -->

## Checklist

- [ ] `./scripts/check-dependency-rule.sh` passes
- [ ] `swift format lint --strict --recursive Sources Tests Package.swift` passes
- [ ] Tests cover the behaviour change (`swift test` needs Xcode — CI runs it otherwise)
- [ ] New user-facing strings go through `localized()` with entries in `en.lproj` **and** `fr.lproj`
- [ ] Commit subjects start with a [Gitmoji](https://gitmoji.dev) and are in English
