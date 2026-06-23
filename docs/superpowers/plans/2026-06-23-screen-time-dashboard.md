# Screen Time Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add day, week, and month Screen Time summaries that show time by category, project, app, and website, with focused-work, distraction, and uncategorized highlights.

**Architecture:** Keep dashboard aggregation in `DailyReplicaCore` as pure presentation logic. Add an app-layer `DashboardService` to load dashboard intervals from `ActivityStore`. Expose dashboard state through `TodayViewModel`; SwiftUI renders passive dashboard sections and calls only view-model intents.

**Tech Stack:** Swift 6, SwiftUI, SQLite via the existing local store, XCTest.

## Global Constraints

- No new package targets or third-party dependencies.
- Strict MVVM-C: views call view-model intents only; services own data loading; core owns aggregation rules.
- Do not push.
- Create one local commit for this dashboard slice after verification.

---

### Task 1: Core Dashboard Aggregation

**Files:**
- Create: `Sources/DailyReplicaCore/ActivityDashboardPresentation.swift`
- Test: `Tests/DailyReplicaCoreTests/ActivityDashboardPresentationTests.swift`
- Modify: `DailyReplica.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces:
  - `DashboardPeriod`
  - `DashboardMetricItem`
  - `DashboardDailyTotal`
  - `ActivityDashboardSummary`
  - `ActivityDashboardPresenter.summary(for:projectSessions:in:calendar:)`
  - `DashboardPeriod.interval(containing:calendar:)`

- [x] Add tests for day/week/month interval calculation.
- [x] Add tests for totals by category, project, app, and website.
- [x] Add tests for focused-work, distraction, and uncategorized durations.
- [x] Implement aggregation by clipping segment durations to the selected interval.
- [x] Add the new core file to the Xcode project.
- [x] Run `swift test --filter ActivityDashboardPresentationTests`.

### Task 2: Dashboard Service And State

**Files:**
- Create: `Sources/DailyReplica/Services/DashboardService.swift`
- Modify: `Sources/DailyReplica/Application/AppState.swift`
- Modify: `Sources/DailyReplica/Coordinators/AppCoordinator.swift`
- Modify: `DailyReplica.xcodeproj/project.pbxproj`
- Test: `Tests/DailyReplicaTests/AppLayerTests.swift`

**Interfaces:**
- Produces:
  - `AppState.dashboardPeriod`
  - `AppState.dashboardSegments`
  - `AppState.dashboardProjectSessions`
  - `AppState.dashboardInterval`
  - `AppState.dashboardSummary`
  - `DashboardService.setPeriod(_:now:)`
  - `DashboardService.reload(now:)`

- [x] Add service tests proving day/week/month period changes fetch the expected interval.
- [x] Add service tests proving fetched segments and sessions update `AppState`.
- [x] Implement `DashboardService` with no UI dependencies.
- [x] Inject `DashboardService` through `AppCoordinator`.
- [x] Add the new service file to the Xcode project.
- [x] Run `swift test --filter DashboardServiceTests`.

### Task 3: Today View Model Dashboard API

**Files:**
- Modify: `Sources/DailyReplica/ViewModels/TodayViewModel.swift`
- Modify: `Sources/DailyReplica/PreviewSupport/PreviewFactory.swift`
- Test: `Tests/DailyReplicaTests/AppLayerTests.swift`

**Interfaces:**
- Produces:
  - `TodayViewModel.dashboardPeriod`
  - `TodayViewModel.dashboardSummary`
  - `TodayViewModel.dashboardIntervalTitle`
  - `TodayViewModel.setDashboardPeriod(_:)`
  - `TodayViewModel.dashboardCategoryItems`
  - `TodayViewModel.dashboardProjectItems`
  - `TodayViewModel.dashboardAppItems`
  - `TodayViewModel.dashboardWebsiteItems`
  - `TodayViewModel.dashboardDailyTotals`

- [x] Add view-model tests proving period changes delegate to `DashboardService`.
- [x] Add view-model tests proving dashboard top lists are exposed in sorted order.
- [x] Update preview fixture with dashboard sample data.
- [x] Run `swift test --filter ViewModelTests`.

### Task 4: Today Dashboard UI

**Files:**
- Modify: `Sources/DailyReplica/Views/Today/TodayView.swift`

**Interfaces:**
- Consumes the view-model API from Task 3 only.

- [x] Add a period segmented picker for Day, Week, and Month.
- [x] Add summary metric tiles for tracked, focused work, distractions, and uncategorized.
- [x] Add compact ranked lists for category, project, app, and website time.
- [x] Add a compact daily totals strip for week/month context.
- [x] Keep timeline editing and segment inspector behavior unchanged.
- [x] Run `swift test --filter ViewModelTests` to compile SwiftUI.

### Task 5: Verification And Commit

- [x] Run `swift test`.
- [x] Run `bash Scripts/build-app.sh debug`.
- [x] Run `xcodebuild -project DailyReplica.xcodeproj -scheme DailyReplica -configuration Debug -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build`.
- [x] Run `git diff --check`.
- [x] Mark this plan complete.
- [x] Commit with `git commit -m "feat: add screen time dashboard"`.
