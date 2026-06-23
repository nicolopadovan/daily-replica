# Daily Replica

Daily Replica is a local-only macOS menu-bar tracker inspired by Daily. It combines a manual "current project/context" selector with automatic tracking of the focused app, focused window title, Chrome URL, category, and idle time.

## What v1 Tracks

- Frontmost app through `NSWorkspace`
- Idle state after 30 seconds without keyboard or mouse input
- Focused window title after Accessibility permission is granted
- Active Google Chrome tab URL after macOS Automation permission is granted
- A separate project/context layer for "what I'm working on"
- A category layer for "what kind of activity this app/URL represents"

All data is stored locally in:

```text
~/Library/Application Support/DailyReplica/activity.sqlite
```

## Build and Test

Run the unit tests:

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

## Using the App

1. Build the app bundle.
2. Launch `.build/DailyReplica.app`.
3. Use the menu-bar item to start tracking and select the current project/context.
4. Open Today to inspect timeline segments and correct a segment's category or context.
5. Open Settings to add categories, project contexts, app bundle rules, and Chrome host rules.

## Smart Prompts

Daily Replica shows a small floating prompt when:

- an app or Chrome host remains unclassified for 2 active minutes
- a focused activity category conflicts with the current context's default category for 5 active minutes

Unclassified prompts can create future classification rules. Timeline corrections only edit the selected segment.
