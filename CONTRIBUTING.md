# Contributing

Daily Replica is an open source Proof of Concept macOS app. Small, focused
issues and pull requests are easiest to review.

## Local Setup

Requirements:

- macOS 14 or newer
- Xcode command line tools with Swift 6

Run the test suite:

```bash
swift test
```

Open the app project in Xcode:

```text
DailyReplica.xcodeproj
```

Build the app bundle:

```bash
bash Scripts/build-app.sh debug
```

The app bundle is written to `.build/DailyReplica.app`.

## Pull Requests

- Open an issue first for larger behavior or architecture changes.
- Keep pull requests focused on one problem.
- Include tests for non-trivial logic.
- Run `swift test` before opening a pull request.
- Do not include local databases, app bundles, `.DS_Store`, or build output.

## Architecture

The app uses MVVM-C in the `DailyReplica` target and keeps domain/data logic in
`DailyReplicaCore`. SwiftUI views should render state and forward user intents
to view models. Coordinators own navigation and window presentation.

`DailyReplica.xcodeproj` is the native macOS app project. `Package.swift`
remains the command-line test/build entrypoint for SwiftPM workflows.
