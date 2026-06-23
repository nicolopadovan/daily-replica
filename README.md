# Daily Replica

Daily Replica is a local-only macOS menu-bar activity tracker inspired by Daily.
It combines a manual project/context selector with automatic tracking for the
frontmost app, focused window title, active Chrome URL, activity category, and
idle time.

The project is an early proof of concept. It is usable for local tracking, but
the data model and release process may still change.

## Features

- Menu-bar tracker for starting, stopping, and switching project context.
- Automatic frontmost-app tracking through `NSWorkspace`.
- Idle detection after 30 seconds without keyboard or mouse input.
- Focused window titles when Accessibility permission is granted.
- Active Google Chrome tab URL capture when macOS Automation permission is granted.
- App bundle and Chrome host classification rules.
- Local timeline view with category/context corrections.
- Smart prompts for long-running unclassified activity and category/context mismatches.
- SQLite storage on the local machine only.

## Install

Download the latest macOS app archive from
[GitHub Releases](https://github.com/nicolopadovan/daily-replica/releases).

1. Download `DailyReplica-*-macos-arm64.zip`.
2. Unzip it and move `DailyReplica.app` to `/Applications`.
3. Open the app from Finder.
4. Grant Accessibility permission if you want focused window titles.
5. Grant Chrome Automation permission if you want active Chrome tab URLs.

Official release archives are Developer ID signed by Nicolò Padovan
(`532NRWLQ2D`) when a signing identity is available. The current binary release
is not notarized, so macOS may ask for approval in System Settings > Privacy &
Security the first time it is opened.

## Data And Privacy

Daily Replica does not sync or upload activity data. The local database lives at:

```text
~/Library/Application Support/DailyReplica/activity.sqlite
```

Tracked data can include app names, bundle IDs, focused window titles, Chrome
URLs, categories, project contexts, and manual notes. Keep that database private
if those details are sensitive.

## Requirements

- macOS 14 or newer
- Xcode or the Xcode Command Line Tools with Swift 6 support
- Google Chrome for URL-based website rules

An Apple Developer account is not required for local development. It is only
needed to produce Developer ID signed or notarized release artifacts.

## Build From Source

Run the tests:

```bash
swift test
```

Build a local app bundle:

```bash
bash Scripts/build-app.sh release
```

The app bundle is created at:

```text
.build/DailyReplica.app
```

To build a signed release bundle:

```bash
DAILY_REPLICA_VERSION=0.1.1 \
DAILY_REPLICA_BUILD_NUMBER=2 \
DAILY_REPLICA_CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
DAILY_REPLICA_CODE_SIGN_TEAM_ID="TEAMID" \
bash Scripts/build-app.sh release
```

Maintainer releases use:

```bash
DAILY_REPLICA_CODE_SIGN_IDENTITY="Developer ID Application: Nicolò Padovan (532NRWLQ2D)" \
DAILY_REPLICA_CODE_SIGN_TEAM_ID="532NRWLQ2D"
```

## Usage

1. Launch `DailyReplica.app`.
2. Use the menu-bar item to start tracking.
3. Select or create the current project/context.
4. Open Today to inspect timeline segments and correct categories or contexts.
5. Open Settings to add categories, project contexts, app bundle rules, and
   Chrome host rules.

## Smart Prompts

Daily Replica shows a small floating prompt when:

- an app or Chrome host remains unclassified for 2 active minutes
- a focused activity category conflicts with the current context's default
  category for 5 active minutes

Unclassified prompts can create future classification rules. Timeline
corrections only edit the selected segment.

## Project Layout

```text
Sources/DailyReplica/       macOS app and SwiftUI views
Sources/DailyReplicaCore/   tracking models, classification, SQLite storage
Tests/DailyReplicaCoreTests core unit tests
Scripts/build-app.sh        local app bundle builder
```

## Contributing

Issues and pull requests are welcome. Before opening a pull request, run:

```bash
swift test
```

## License

No license has been selected yet. Until one is added, this repository is source
available but not broadly reusable as open source.
