# Timeline Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users split a selected activity segment, merge it with an adjacent segment, and then reclassify the corrected range by category or project.

**Architecture:** Keep editing rules in `DailyReplicaCore` through `ActivitySegmentReducer`. Keep persistence orchestration in `SegmentEditingService`, presentation state and commands in `TodayViewModel`, and SwiftUI views as passive renderers. Add only the store deletion capability required for merges.

**Tech Stack:** Swift 6, SwiftUI, AppKit macOS 14, SQLite via the existing local store, XCTest.

## Global Constraints

- No new package targets or third-party dependencies.
- Preserve the existing SQLite schema except for no-op code additions; do not migrate segment columns.
- Strict MVVM-C: views call view-model intents only; services own app behavior; core owns editing rules.
- Local commits only; do not push.

---

### Task 1: Core Segment Split And Merge

**Files:**
- Modify: `Sources/DailyReplicaCore/ActivitySegmentReducer.swift`
- Test: `Tests/DailyReplicaCoreTests/ActivitySegmentReducerTests.swift`

**Interfaces:**
- Produces:
  - `splitSegment(id:at:in:editedAt:) -> (left: ActivitySegment, right: ActivitySegment)?`
  - `mergeSegment(id:withAdjacentID:in:editedAt:) -> ActivitySegment?`

- [x] Add reducer tests for splitting a segment into two persisted-ready segments.
- [x] Add reducer tests rejecting split times at or outside segment bounds.
- [x] Add reducer tests merging a selected segment with previous/next adjacent segments while preserving the selected segment metadata and ID.
- [x] Implement the reducer methods with no persistence concerns.
- [x] Run `swift test --filter ActivitySegmentReducerTests`.

### Task 2: Store Delete Support

**Files:**
- Modify: `Sources/DailyReplica/Infrastructure/AppProtocols.swift`
- Modify: `Sources/DailyReplicaCore/SQLiteActivityStore.swift`
- Modify: `Tests/DailyReplicaCoreTests/SQLiteActivityStoreTests.swift`
- Modify: `Tests/DailyReplicaTests/AppLayerTests.swift`

**Interfaces:**
- Produces:
  - `ActivityStore.deleteSegment(id: UUID) throws`
  - `SQLiteActivityStore.deleteSegment(id:)`

- [x] Add SQLite test proving a deleted segment no longer appears in `fetchSegments(in:)`.
- [x] Add the protocol method and in-memory test-store implementation.
- [x] Implement SQLite `DELETE FROM activity_segments WHERE id = ?`.
- [x] Run `swift test --filter SQLiteActivityStoreTests`.

### Task 3: Segment Editing Service Commands

**Files:**
- Modify: `Sources/DailyReplica/Services/SegmentEditingService.swift`
- Test: `Tests/DailyReplicaTests/AppLayerTests.swift`

**Interfaces:**
- Produces:
  - `splitSegment(segmentID:at:) -> ActivitySegment?`
  - `mergeSegment(segmentID:withAdjacentSegmentID:) -> ActivitySegment?`
  - `segment(before:) -> ActivitySegment?`
  - `segment(after:) -> ActivitySegment?`

- [x] Add service tests proving split upserts both halves and selects the right-half return value.
- [x] Add service tests proving merge upserts the merged selected segment and deletes the neighbor.
- [x] Implement service methods by delegating edit rules to `ActivitySegmentReducer`.
- [x] Run `swift test --filter SegmentEditingServiceTests`.

### Task 4: Today View Model And UI

**Files:**
- Modify: `Sources/DailyReplica/ViewModels/TodayViewModel.swift`
- Modify: `Sources/DailyReplica/Views/Today/TodayView.swift`
- Test: `Tests/DailyReplicaTests/AppLayerTests.swift`

**Interfaces:**
- Produces view-model intents:
  - `splitTime`
  - `resetSplitTime(for:)`
  - `splitSelectedSegment()`
  - `mergeSelectedSegmentWithPrevious()`
  - `mergeSelectedSegmentWithNext()`
  - `canSplitSelectedSegment`
  - `canMergeSelectedSegmentWithPrevious`
  - `canMergeSelectedSegmentWithNext`

- [x] Add view-model tests for split selecting the right half.
- [x] Add view-model tests for merge preserving a valid selected segment.
- [x] Add inspector controls: split time picker, split button, merge previous, merge next.
- [x] Keep category/project controls unchanged; after splitting, they apply to the selected corrected range.
- [x] Run `swift test --filter ViewModelTests`.

### Task 5: Verification And Commit

**Files:**
- No source changes beyond Tasks 1-4.

- [x] Run `swift test`.
- [x] Run `bash Scripts/build-app.sh debug`.
- [x] Run `xcodebuild -project DailyReplica.xcodeproj -scheme DailyReplica -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`.
- [x] Run `git diff --check`.
- [x] Commit with `git commit -m "feat: add timeline segment editing"`.
