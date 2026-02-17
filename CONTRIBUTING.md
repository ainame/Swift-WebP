# Contributing

Contributions are welcome through issues and pull requests.

## Development Requirements

- Swift 6.2 toolchain
- Xcode with Swift 6.2 support (for Apple platform checks)

## Local Validation

Run before opening a PR:

```bash
swift build
swift test
```

## Formatting

SwiftFormat is integrated as an SPM command plugin dependency (Nick Lockwood).

```bash
swift package plugin --allow-writing-to-package-directory swiftformat
```

## CI

GitHub Actions validates:

- macOS build + test
- Linux build + test
- iOS package build (`xcodebuild`)

## Changelog

For user-facing changes, update [CHANGELOG.md](CHANGELOG.md) in the same PR.

## Release Process

1. Ensure CI is green on `major-bump`/release branch.
2. Finalize release notes in `CHANGELOG.md`.
3. Create a git tag without `v` prefix (example: `0.6.0`).
4. Create GitHub release notes from changelog entries.
