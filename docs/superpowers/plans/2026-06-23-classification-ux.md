# Classification UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve classification workflows by suggesting rules from repeated corrections, bulk-classifying today's uncategorized apps and hosts, and making existing rules editable.

**Architecture:** Keep candidate detection as pure `DailyReplicaCore` presentation logic. Reuse `LibraryService` for all rule and segment persistence. `SettingsViewModel` exposes candidate lists and intents; `SettingsView` remains a passive SwiftUI renderer.

**Tech Stack:** Swift 6, SwiftUI, SQLite through the existing `ActivityStore`, XCTest.

## Global Constraints

- No new dependencies.
- No new package targets.
- No SQLite schema migration.
- Views do not call stores or services directly.
- Existing prompt-created rules keep working.
- Commit locally only; do not push.

---

### Task 1: Core Classification Candidates

**Files:**
- Create: `Sources/DailyReplicaCore/ClassificationCandidates.swift`
- Create: `Tests/DailyReplicaCoreTests/ClassificationCandidatesTests.swift`
- Modify: `DailyReplica.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces:
  - `ClassificationCandidate`
  - `ClassificationCandidatePresenter.ruleSuggestions(from:rules:minimumCorrections:)`
  - `ClassificationCandidatePresenter.unclassifiedCandidates(from:rules:)`

- [x] Add tests for repeated manual corrections producing one app rule suggestion after two matching corrected segments.
- [x] Add tests for repeated manual host corrections producing one website rule suggestion using `urlHost` or `urlString`.
- [x] Add tests proving existing rules suppress matching suggestions and uncategorized candidates.
- [x] Add tests proving uncategorized candidates are sorted by duration, then title.
- [x] Implement `ClassificationCandidate` with `kind`, `pattern`, `suggestedCategoryID`, `title`, `subtitle`, `segmentCount`, `duration`, and stable `id`.
- [x] Implement candidate extraction by preferring hosts over app bundle IDs when a segment has a host.
- [x] Add `ClassificationCandidates.swift` to the Xcode project.
- [x] Run `swift test --filter ClassificationCandidatesTests`.

### Task 2: Library Rule And Bulk Classification Mutations

**Files:**
- Modify: `Sources/DailyReplica/Services/LibraryService.swift`
- Test: `Tests/DailyReplicaTests/AppLayerTests.swift`

**Interfaces:**
- Consumes:
  - `ClassificationCandidate.kind`
  - `ClassificationCandidate.pattern`
  - `ClassificationCandidate.suggestedCategoryID`
- Produces:
  - `LibraryService.addRule(kind:pattern:categoryID:) -> ClassificationRule?`
  - `LibraryService.updateRuleCategory(id:categoryID:)`
  - `LibraryService.classifyUncategorized(kind:pattern:categoryID:) -> Int`

- [x] Add a service test proving duplicate rule creation updates the existing rule category instead of appending a duplicate.
- [x] Add a service test proving `updateRuleCategory(id:categoryID:)` persists and updates `state.rules`.
- [x] Add a service test proving `classifyUncategorized(kind:pattern:categoryID:)` creates a rule, updates matching uncategorized today segments, and persists the changed segments.
- [x] Change `addRule` to return the inserted or updated rule while keeping existing callers source-compatible.
- [x] Implement `updateRuleCategory(id:categoryID:)` by editing the existing rule and calling `store.upsertRule(_:)`.
- [x] Implement `classifyUncategorized(kind:pattern:categoryID:)` using today's in-memory segments and `store.upsertSegment(_:)`.
- [x] Run `swift test --filter LibraryServiceTests`.

### Task 3: Settings View Model Classification API

**Files:**
- Modify: `Sources/DailyReplica/ViewModels/SettingsViewModel.swift`
- Modify: `Sources/DailyReplica/PreviewSupport/PreviewFactory.swift`
- Test: `Tests/DailyReplicaTests/AppLayerTests.swift`

**Interfaces:**
- Consumes:
  - `ClassificationCandidatePresenter.ruleSuggestions(from:rules:minimumCorrections:)`
  - `ClassificationCandidatePresenter.unclassifiedCandidates(from:rules:)`
  - `LibraryService.updateRuleCategory(id:categoryID:)`
  - `LibraryService.classifyUncategorized(kind:pattern:categoryID:)`
- Produces:
  - `SettingsViewModel.ruleSuggestions`
  - `SettingsViewModel.unclassifiedCandidates`
  - `SettingsViewModel.bulkRuleCategoryID`
  - `SettingsViewModel.acceptRuleSuggestion(_:)`
  - `SettingsViewModel.classifyUncategorized(_:)`
  - `SettingsViewModel.updateRuleCategory(id:categoryID:)`

- [x] Add a view-model test proving `ruleSuggestions` exposes repeated manual corrections.
- [x] Add a view-model test proving accepting a suggestion creates a rule and removes that suggestion.
- [x] Add a view-model test proving bulk classification delegates and uses `bulkRuleCategoryID`.
- [x] Update preview sample data with repeated corrections and uncategorized segments.
- [x] Implement the view-model properties and intents.
- [x] Run `swift test --filter ViewModelTests`.

### Task 4: Settings Rules UI

**Files:**
- Modify: `Sources/DailyReplica/Views/Settings/SettingsView.swift`

**Interfaces:**
- Consumes the Settings view-model API from Task 3 only.

- [x] Add a "Suggested rules" section in the rules pane with an "Add rule" button for each suggestion.
- [x] Add an "Unsorted today" section in the rules pane with one category picker and a "Classify" button for each uncategorized candidate.
- [x] Change existing rule rows to use a category picker so rules can be edited without deleting and recreating them.
- [x] Keep rule deletion available.
- [x] Run `swift test --filter ViewModelTests` to compile the SwiftUI changes.

### Task 5: Verification And Commit

- [x] Run `swift test`.
- [x] Run `bash Scripts/build-app.sh debug`.
- [x] Run `xcodebuild -project DailyReplica.xcodeproj -scheme DailyReplica -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`.
- [x] Run `git diff --check`.
- [x] Mark this plan complete.
- [x] Commit with `git commit -m "feat: improve classification ux"`.
