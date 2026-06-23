# Privacy And OSS Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local data export and deletion controls, and make permission/privacy behavior clearer for users and contributors.

**Architecture:** Keep export formatting in `DailyReplicaCore` so it is testable without UI. Add only the store mutations needed for deletion. Add a small app-layer `PrivacyService` that coordinates store export/reset with `AppState`; `SettingsViewModel` exposes intents and `SettingsView` uses native SwiftUI file exporters.

**Tech Stack:** Swift 6, SwiftUI, UniformTypeIdentifiers, SQLite through the existing store, XCTest.

## Global Constraints

- No new dependencies.
- No new package targets.
- No SQLite schema migration.
- Keep exports local; no networking.
- Destructive controls require UI confirmation.
- Commit locally only; do not push.

---

### Task 1: Core Export Formatting

**Files:**
- Create: `Sources/DailyReplicaCore/ActivityDataExport.swift`
- Create: `Tests/DailyReplicaCoreTests/ActivityDataExportTests.swift`
- Modify: `DailyReplica.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces:
  - `ActivityExportSnapshot`
  - `ActivityDataExporter.jsonData(snapshot:) throws -> Data`
  - `ActivityDataExporter.segmentsCSV(segments:) -> String`

- [x] Add a JSON export test proving categories, contexts, rules, segments, and project sessions encode into one snapshot.
- [x] Add a CSV export test proving segment fields are included and quotes are escaped.
- [x] Implement `ActivityExportSnapshot: Codable, Equatable`.
- [x] Implement deterministic JSON export with `JSONEncoder.outputFormatting = [.prettyPrinted, .sortedKeys]`.
- [x] Implement CSV export for activity segments only, with a header row.
- [x] Add `ActivityDataExport.swift` to the Xcode project.
- [x] Run `swift test --filter ActivityDataExportTests`.

### Task 2: Store Delete And Export Access

**Files:**
- Modify: `Sources/DailyReplica/Infrastructure/AppProtocols.swift`
- Modify: `Sources/DailyReplicaCore/SQLiteActivityStore.swift`
- Test: `Tests/DailyReplicaCoreTests/SQLiteActivityStoreTests.swift`

**Interfaces:**
- Produces:
  - `ActivityStore.deleteAllActivityData() throws`
  - `ActivityStore.deleteAllUserData() throws`
  - `SQLiteActivityStore.deleteAllActivityData() throws`
  - `SQLiteActivityStore.deleteAllUserData() throws`

- [x] Add a SQLite test proving `deleteAllActivityData()` removes segments and project sessions while keeping rules and contexts.
- [x] Add a SQLite test proving `deleteAllUserData()` removes segments, project sessions, rules, and custom contexts while preserving built-in categories.
- [x] Add the two delete methods to `ActivityStore`.
- [x] Implement the two SQLite delete methods with simple `DELETE` statements.
- [x] Update in-memory and preview stores to satisfy the protocol.
- [x] Run `swift test --filter SQLiteActivityStoreTests`.

### Task 3: Privacy Service And View Model API

**Files:**
- Create: `Sources/DailyReplica/Services/PrivacyService.swift`
- Modify: `Sources/DailyReplica/Coordinators/AppCoordinator.swift`
- Modify: `Sources/DailyReplica/ViewModels/SettingsViewModel.swift`
- Modify: `Sources/DailyReplica/PreviewSupport/PreviewFactory.swift`
- Test: `Tests/DailyReplicaTests/AppLayerTests.swift`
- Modify: `DailyReplica.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces:
  - `PrivacyService.exportJSONData() throws -> Data`
  - `PrivacyService.exportSegmentsCSVData() throws -> Data`
  - `PrivacyService.clearActivityData()`
  - `PrivacyService.resetAllData()`
  - `SettingsViewModel.exportJSONText() -> String?`
  - `SettingsViewModel.exportSegmentsCSVText() -> String?`
  - `SettingsViewModel.clearActivityData()`
  - `SettingsViewModel.resetAllData()`

- [x] Add service tests proving JSON export includes stored data.
- [x] Add service tests proving clearing activity updates store and `AppState`.
- [x] Add service tests proving resetting all data clears user-created local state.
- [x] Add view-model tests proving export text is returned and reset intents delegate.
- [x] Implement `PrivacyService` using existing `ActivityStore` methods and wide date intervals for export.
- [x] Inject `PrivacyService` into `SettingsViewModel` from `AppCoordinator`, tests, and previews.
- [x] Add `PrivacyService.swift` to the Xcode project.
- [x] Run `swift test --filter PrivacyServiceTests`.
- [x] Run `swift test --filter ViewModelTests`.

### Task 4: Settings Privacy UI And Docs

**Files:**
- Modify: `Sources/DailyReplica/Views/Settings/SettingsView.swift`
- Modify: `README.md`
- Modify: `SECURITY.md`

**Interfaces:**
- Consumes the Settings view-model API from Task 3 only.

- [x] Add native JSON and CSV export buttons to the permissions/privacy pane.
- [x] Add confirmed "Clear activity history" and "Reset all local data" buttons.
- [x] Expand permission copy to explain Accessibility and Chrome Automation fallback behavior.
- [x] Update `README.md` with local data location, export, and reset behavior.
- [x] Update `SECURITY.md` with local data deletion/export notes.
- [x] Run `swift test --filter ViewModelTests` to compile SwiftUI.

### Task 5: Verification And Commit

- [x] Run `swift test`.
- [x] Run `bash Scripts/build-app.sh debug`.
- [x] Run `xcodebuild -project DailyReplica.xcodeproj -scheme DailyReplica -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`.
- [x] Run `git diff --check`.
- [x] Mark this plan complete.
- [x] Commit with `git commit -m "feat: add privacy controls and export"`.
