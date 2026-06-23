# Project Session Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make "What are you working on?" a first-class project session timeline, with persisted start/end times and automatic attribution of tracked app activity to the active project.

**Architecture:** Add `ProjectSession` to `DailyReplicaCore` and persist it in SQLite. Add a focused `ProjectSessionService` in the app layer to own current-project switching and session lifecycle. Menu/Today view models expose project-session display state and intents; SwiftUI views stay passive.

**Tech Stack:** Swift 6, SwiftUI, SQLite via the existing local store, XCTest.

## Global Constraints

- No new package targets or third-party dependencies.
- Preserve existing activity segment schema and behavior.
- Strict MVVM-C: views call view-model intents only; services own app behavior; core owns data shapes.
- Local commits only; do not push.

---

### Task 1: Core Project Session Model

**Files:**
- Modify: `Sources/DailyReplicaCore/Models.swift`

**Interfaces:**
- Produces:
  - `ProjectSession`
  - `ProjectSession.duration(until:)`

- [x] Add `ProjectSession` with `id`, `contextID`, `contextName`, `start`, `end`, `createdAt`, and `updatedAt`.
- [x] Add `duration(until:)` returning elapsed time to `end` or the supplied date.

### Task 2: SQLite Project Session Persistence

**Files:**
- Modify: `Sources/DailyReplica/Infrastructure/AppProtocols.swift`
- Modify: `Sources/DailyReplicaCore/SQLiteActivityStore.swift`
- Modify: `Tests/DailyReplicaCoreTests/SQLiteActivityStoreTests.swift`
- Modify: `Tests/DailyReplicaTests/AppLayerTests.swift`
- Modify: `Sources/DailyReplica/PreviewSupport/PreviewFactory.swift`

**Interfaces:**
- Produces:
  - `ActivityStore.fetchProjectSessions(in:)`
  - `ActivityStore.fetchOpenProjectSession()`
  - `ActivityStore.upsertProjectSession(_:)`

- [x] Add SQLite tests for inserting, updating, fetching by day interval, and fetching the open session.
- [x] Add `project_sessions` table with `id`, `context_id`, `context_name`, `start_at`, nullable `end_at`, `created_at`, and `updated_at`.
- [x] Add app protocol and fake-store implementations.
- [x] Run `swift test --filter SQLiteActivityStoreTests`.

### Task 3: Project Session Service

**Files:**
- Create: `Sources/DailyReplica/Services/ProjectSessionService.swift`
- Modify: `Sources/DailyReplica/Application/AppState.swift`
- Modify: `Sources/DailyReplica/Services/LibraryService.swift`
- Test: `Tests/DailyReplicaTests/AppLayerTests.swift`

**Interfaces:**
- Produces:
  - `AppState.todayProjectSessions`
  - `AppState.activeProjectSession`
  - `ProjectSessionService.loadState(now:)`
  - `ProjectSessionService.setCurrentContext(id:now:)`
  - `ProjectSessionService.closeActiveSession(now:)`
  - `ProjectSessionService.reloadToday()`
  - `LibraryService.addContext(name:defaultCategoryID:selectCurrent:)`

- [x] Add service tests for switching projects closing the old session and starting a new one.
- [x] Add service tests for selecting no project closing the active session.
- [x] Add service tests for loading an open session and using it as current context.
- [x] Change project creation so correction flows can create projects without switching the active session.
- [x] Run `swift test --filter ProjectSessionServiceTests`.

### Task 4: MVVM-C Wiring And UI

**Files:**
- Modify: `Sources/DailyReplica/Coordinators/AppCoordinator.swift`
- Modify: `Sources/DailyReplica/ViewModels/MenuBarViewModel.swift`
- Modify: `Sources/DailyReplica/ViewModels/TodayViewModel.swift`
- Modify: `Sources/DailyReplica/Views/MenuBar/MenuBarView.swift`
- Modify: `Sources/DailyReplica/Views/Today/TodayView.swift`
- Modify: `Sources/DailyReplica/PreviewSupport/PreviewFactory.swift`
- Modify: `DailyReplica.xcodeproj/project.pbxproj`
- Test: `Tests/DailyReplicaTests/AppLayerTests.swift`

**Interfaces:**
- Produces:
  - `MenuBarViewModel.currentProjectElapsed`
  - `MenuBarViewModel.setCurrentContext(selection:)` backed by `ProjectSessionService`
  - `TodayViewModel.activeProjectSession`

- [x] Inject `ProjectSessionService` through `AppCoordinator`.
- [x] Menu project changes call project-session service, then capture a tracking boundary when tracking.
- [x] Creating a project from the menu starts a session for that project.
- [x] Creating a project from Today correction does not switch the active session.
- [x] Show active project elapsed time in the menu and Today header.
- [x] Add the new service file to the Xcode project.
- [x] Run `swift test --filter ViewModelTests`.

### Task 5: Verification And Commit

- [x] Run `swift test`.
- [x] Run `bash Scripts/build-app.sh debug`.
- [x] Run `xcodebuild -project DailyReplica.xcodeproj -scheme DailyReplica -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`.
- [x] Run `git diff --check`.
- [x] Commit with `git commit -m "feat: add project session tracking"`.
