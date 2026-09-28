# Contributing

Contributions are welcome through issues and pull requests.

## Development Requirements

- Swift 6.4.0 for local development, selected by `.swift-version`. The package minimum is Swift 6.2 (`swift-tools-version: 6.2`).
- Xcode 26.2+ (Swift 6.2.3 support) for Apple platform checks

## Local Validation

Run before opening a PR:

```bash
swift build
swift test
```

## Formatting

Formatting uses the `swift format` (swift-format) bundled with the Swift toolchain, configured by `.swift-format`.
There is no formatter dependency in `Package.swift`.

```bash
make format   # rewrite files in place
make lint     # check only
```

## CI

GitHub Actions validates:

- macOS build + test
- Linux build + test

## Changelog

For user-facing changes, update [CHANGELOG.md](CHANGELOG.md) in the same PR.

## Release Process

1. Ensure CI is green on `major-bump`/release branch.
2. Finalize release notes in `CHANGELOG.md`.
3. Create a git tag without `v` prefix (example: `0.6.0`).
4. Create GitHub release notes from changelog entries.
