<div align="center">

# 🌤️ Daily Replica

A tiny macOS menu bar app for remembering what your day looked like.

[![Release](https://img.shields.io/github/v/release/nicolopadovan/daily-replica?label=release)](https://github.com/nicolopadovan/daily-replica/releases)
![macOS](https://img.shields.io/badge/macOS-14%2B-black)
![Swift](https://img.shields.io/badge/Swift-6-orange)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

</div>

Daily Replica sits in your menu bar and gives you a lightweight timeline of your
workday. Pick what you are working on, let the app quietly follow along, and
clean things up later when the day gets messy.

Daily Replica is local-first. Activity data is stored on your Mac, and optional
macOS permissions are used only to make the local timeline more useful.

## ✨ Features

- 🕘 Track your day from the menu bar
- 🗂️ Switch between projects and contexts
- 🎨 Organize time into simple categories
- 🧾 Review a clean timeline of your day
- ✏️ Fix anything that was categorized wrong
- 🔒 Designed to stay local to your Mac
- ⬆️ Check for signed updates with Sparkle

## 📦 Installation

Download the latest version from
[GitHub Releases](https://github.com/nicolopadovan/daily-replica/releases).

1. Download `DailyReplica-*-macos-arm64.zip`
2. Unzip it
3. Move `DailyReplica.app` to your `Applications` folder
4. Open it and start tracking

If macOS blocks the first launch, open **System Settings → Privacy & Security**
and allow Daily Replica from there.

Release builds are Developer ID signed and notarized. Daily Replica uses
Sparkle to check the appcast at
`https://nicolopadovan.github.io/daily-replica/appcast.xml` and can install
future signed updates from inside the app.

## 🧭 Usage

1. Open Daily Replica
2. Start tracking from the menu bar
3. Pick what you are working on
4. Check your timeline when you want a recap
5. Adjust categories when needed

## 🔒 Local Data And Privacy

Daily Replica stores its SQLite database locally at:

```text
~/Library/Application Support/DailyReplica/activity.sqlite
```

From **Settings → Permissions**, you can export local data as JSON, export
activity segments as CSV, clear activity history, or reset all local data.

Accessibility permission is used for focused window titles. Chrome Automation is
used only to read the active Chrome tab URL. If either permission is denied,
Daily Replica keeps tracking at the app level and leaves unavailable details
blank.

## 🛠️ Build From Source

For app development in Xcode, open:

```text
DailyReplica.xcodeproj
```

For command-line builds and tests:

```bash
swift test
bash Scripts/build-app.sh debug
```

For a fast regression check focused on startup + tracking correctness, run:

```bash
bash Scripts/health-check.sh
```

The app will be created at:

```text
.build/DailyReplica.app
```

Release packaging is Xcode based and requires Developer ID signing,
notarization, and the matching Sparkle private key in Keychain:

```bash
DAILY_REPLICA_NOTARY_PROFILE="<notarytool profile>" \
bash Scripts/build-app.sh release
```

The release zip is written to `.build/releases/`, and `docs/appcast.xml` is
updated from Sparkle's `generate_appcast` output.

## ❓ FAQ

### Is this production ready?

Not yet. Daily Replica is still an early app, but it is ready enough to try.

### Is it security hardened?

No. Daily Replica has not had a security audit or hardening pass yet. Treat it
as experimental software and only install builds you trust.

### Does it work offline?

Yes. Daily Replica is designed as a local macOS app.

### Is there a Homebrew install?

Not yet. For now, use the release zip.

## 🙌 Contributing

Issues and pull requests are welcome. If something feels confusing, broken, or
missing, open an issue first so it can be discussed.

See [CONTRIBUTING.md](CONTRIBUTING.md) for local setup, architecture notes, and
pull request expectations.

## 🔐 Security

Daily Replica is experimental and has not had a formal security audit. See
[SECURITY.md](SECURITY.md) for supported versions and vulnerability reporting.

## 📄 License

MIT License. See [LICENSE](LICENSE).
