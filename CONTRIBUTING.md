# Contributing

Daily Replica is an open source Proof of Concept macOS app. Small, focused
issues and pull requests are easiest to review.

## Local Setup

Requirements:

- macOS 14 or newer
- Xcode command line tools with Swift 6
- Xcode with access to `DailyReplica.xcodeproj`

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

The build script uses `xcodebuild`; SwiftPM remains useful for tests and package
validation, but the Xcode project is the canonical app build path.

## Release Builds

Release builds are produced from an Xcode archive and exported with Developer ID
signing. They are notarized, stapled, zipped with `ditto`, and added to the
Sparkle appcast.

Prerequisites:

- A Developer ID Application certificate available to Xcode.
- A notarytool keychain profile created with `xcrun notarytool store-credentials`.
- The matching Sparkle private key in Keychain. The public key is committed in
  the Xcode build setting `SPARKLE_PUBLIC_ED_KEY`.
- Sparkle's `generate_appcast` tool available from the Xcode-resolved Sparkle
  package, or `DAILY_REPLICA_SPARKLE_TOOLS_DIR` pointing at a directory that
  contains it.

Release command:

```bash
DAILY_REPLICA_VERSION="0.1.2" \
DAILY_REPLICA_BUILD_NUMBER="3" \
DAILY_REPLICA_NOTARY_PROFILE="<notarytool profile>" \
bash Scripts/build-app.sh release
```

Outputs:

- `.build/releases/DailyReplica-$DAILY_REPLICA_VERSION-macos-arm64.zip`
- `docs/appcast.xml`

Never commit the Sparkle private key, local app bundles, archives, notarization
logs, or exported release artifacts.

## Pull Requests

- Open an issue first for larger behavior or architecture changes.
- Keep pull requests focused on one problem.
- Include tests for non-trivial logic.
- Run `swift test` and `bash Scripts/build-app.sh debug` before opening a pull request when the change touches app code.
- Do not include local databases, app bundles, `.DS_Store`, or build output.

## Architecture

The app uses MVVM-C in the `DailyReplica` target and keeps domain/data logic in
`DailyReplicaCore`. SwiftUI views should render state and forward user intents
to view models. Coordinators own navigation and window presentation.

`DailyReplica.xcodeproj` is the native macOS app project. `Package.swift`
remains the command-line test/build entrypoint for SwiftPM workflows.
