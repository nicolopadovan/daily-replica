import DailyReplicaCore
@testable import DailyReplica
import XCTest

@MainActor
final class LibraryServiceTests: XCTestCase {
    func testAddCategoryTrimsRejectsEmptyAndSorts() {
        let harness = AppHarness()

        XCTAssertNil(harness.libraryService.addCategory(name: "   "))
        XCTAssertNotNil(harness.libraryService.addCategory(name: "  Zeta  "))
        XCTAssertNotNil(harness.libraryService.addCategory(name: "Alpha"))

        XCTAssertEqual(harness.state.categories.map(\.name), ["Alpha", "Zeta"])
        XCTAssertEqual(harness.store.categories.map(\.id), ["zeta", "alpha"])
    }

    func testAddContextPersistsSortsAndSelectsCurrentContext() {
        let harness = AppHarness()

        let beta = harness.libraryService.addContext(name: "Beta", defaultCategoryID: CategoryID.work.rawValue)
        let alpha = harness.libraryService.addContext(name: "Alpha", defaultCategoryID: CategoryID.personal.rawValue)

        XCTAssertEqual(harness.state.contexts.map(\.name), ["Alpha", "Beta"])
        XCTAssertEqual(harness.state.currentContextID, alpha?.id)
        XCTAssertEqual(harness.contextPersistence.savedID, alpha?.id)
        XCTAssertEqual(harness.store.contexts.map(\.id).sorted(), [alpha?.id, beta?.id].compactMap { $0 }.sorted())
    }

    func testAddRuleNormalizesChromeHostAndStoresRule() {
        let harness = AppHarness()

        harness.libraryService.addRule(kind: .chromeHost, pattern: " GitHub.COM ", categoryID: CategoryID.work.rawValue)

        XCTAssertEqual(harness.state.rules.first?.pattern, "github.com")
        XCTAssertEqual(harness.store.rules.first?.pattern, "github.com")
    }

    func testAddRuleUpdatesDuplicateRuleCategory() {
        let harness = AppHarness()

        harness.libraryService.addRule(kind: .appBundleID, pattern: "com.example.App", categoryID: CategoryID.work.rawValue)
        harness.libraryService.addRule(kind: .appBundleID, pattern: "com.example.App", categoryID: CategoryID.personal.rawValue)

        XCTAssertEqual(harness.state.rules.count, 1)
        XCTAssertEqual(harness.state.rules.first?.categoryID, CategoryID.personal.rawValue)
        XCTAssertEqual(harness.store.rules.count, 1)
        XCTAssertEqual(harness.store.rules.first?.categoryID, CategoryID.personal.rawValue)
    }

    func testUpdateRuleCategoryPersistsExistingRule() {
        let harness = AppHarness()
        let rule = ClassificationRule(kind: .chromeHost, pattern: "github.com", categoryID: CategoryID.work.rawValue)
        harness.state.rules = [rule]
        harness.store.rules = [rule]

        harness.libraryService.updateRuleCategory(id: rule.id, categoryID: CategoryID.personal.rawValue)

        XCTAssertEqual(harness.state.rules.first?.categoryID, CategoryID.personal.rawValue)
        XCTAssertEqual(harness.store.rules.first?.categoryID, CategoryID.personal.rawValue)
    }

    func testClassifyUncategorizedCreatesRuleAndPersistsMatchingSegments() {
        let harness = AppHarness()
        let matching = ActivitySegment(
            start: Date(timeIntervalSince1970: 10),
            end: Date(timeIntervalSince1970: 70),
            state: .active,
            appBundleID: "com.google.Chrome",
            appName: "Google Chrome",
            urlHost: "github.com",
            categoryID: CategoryID.unclassified.rawValue
        )
        let subdomain = ActivitySegment(
            start: Date(timeIntervalSince1970: 70),
            end: Date(timeIntervalSince1970: 130),
            state: .active,
            appBundleID: "com.google.Chrome",
            appName: "Google Chrome",
            urlHost: "docs.github.com",
            categoryID: CategoryID.unclassified.rawValue
        )
        let other = ActivitySegment(
            start: Date(timeIntervalSince1970: 130),
            end: Date(timeIntervalSince1970: 190),
            state: .active,
            appBundleID: "com.apple.Safari",
            appName: "Safari",
            categoryID: CategoryID.unclassified.rawValue
        )
        harness.state.todaySegments = [matching, subdomain, other]
        harness.store.segments = harness.state.todaySegments

        let count = harness.libraryService.classifyUncategorized(
            kind: .chromeHost,
            pattern: "github.com",
            categoryID: CategoryID.work.rawValue
        )

        XCTAssertEqual(count, 2)
        XCTAssertEqual(harness.state.rules.first?.pattern, "github.com")
        XCTAssertEqual(harness.state.todaySegments.map(\.categoryID), [
            CategoryID.work.rawValue,
            CategoryID.work.rawValue,
            CategoryID.unclassified.rawValue
        ])
        XCTAssertEqual(harness.state.todaySegments[0].manualCategoryID, CategoryID.work.rawValue)
        XCTAssertEqual(harness.store.upsertedSegments.count, 2)
    }
}

@MainActor
final class SegmentEditingServiceTests: XCTestCase {
    func testEditsSegmentCategoryAndContextOnceThenPersists() {
        let harness = AppHarness()
        let context = ProjectContext(name: "Client", defaultCategoryID: CategoryID.work.rawValue)
        let segment = ActivitySegment(
            start: Date(timeIntervalSince1970: 10),
            end: Date(timeIntervalSince1970: 20),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.unclassified.rawValue
        )
        harness.state.contexts = [context]
        harness.state.todaySegments = [segment]

        harness.segmentEditingService.editCategory(segmentID: segment.id, categoryID: CategoryID.work.rawValue)
        harness.segmentEditingService.editContext(segmentID: segment.id, contextID: context.id)

        XCTAssertEqual(harness.state.todaySegments.first?.categoryID, CategoryID.work.rawValue)
        XCTAssertEqual(harness.state.todaySegments.first?.manualCategoryID, CategoryID.work.rawValue)
        XCTAssertEqual(harness.state.todaySegments.first?.contextID, context.id)
        XCTAssertEqual(harness.store.upsertedSegments.count, 2)
        XCTAssertEqual(harness.store.upsertedSegments.last?.contextName, "Client")
    }

    func testMarkInactiveClearsEntryDetailsAndPersistsSameSegment() {
        let harness = AppHarness()
        let context = ProjectContext(name: "Client", defaultCategoryID: CategoryID.work.rawValue)
        let segment = ActivitySegment(
            start: Date(timeIntervalSince1970: 10),
            end: Date(timeIntervalSince1970: 20),
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode",
            windowTitle: "Daily Replica",
            urlString: "https://example.com",
            urlHost: "example.com",
            categoryID: CategoryID.work.rawValue,
            contextID: context.id,
            contextName: context.name,
            manualCategoryID: CategoryID.work.rawValue,
            manualContextID: context.id,
            manualNote: "wrong"
        )
        harness.state.todaySegments = [segment]

        harness.segmentEditingService.markInactive(segmentID: segment.id)

        let updated = harness.state.todaySegments.first
        XCTAssertEqual(updated?.id, segment.id)
        XCTAssertEqual(updated?.start, segment.start)
        XCTAssertEqual(updated?.end, segment.end)
        XCTAssertEqual(updated?.state, .inactive)
        XCTAssertEqual(updated?.categoryID, CategoryID.inactive.rawValue)
        XCTAssertNil(updated?.appBundleID)
        XCTAssertNil(updated?.appName)
        XCTAssertNil(updated?.windowTitle)
        XCTAssertNil(updated?.urlString)
        XCTAssertNil(updated?.urlHost)
        XCTAssertNil(updated?.contextID)
        XCTAssertNil(updated?.contextName)
        XCTAssertFalse(updated?.hasManualOverride ?? true)
        XCTAssertEqual(harness.store.upsertedSegments.last?.id, segment.id)
        XCTAssertEqual(harness.store.upsertedSegments.last?.state, .inactive)
    }

    func testSplitsSegmentAndPersistsBothHalves() {
        let harness = AppHarness()
        let start = Date(timeIntervalSince1970: 100)
        let segment = ActivitySegment(
            start: start,
            end: start.addingTimeInterval(80),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue
        )
        harness.state.todaySegments = [segment]

        let right = harness.segmentEditingService.splitSegment(
            segmentID: segment.id,
            at: start.addingTimeInterval(30)
        )

        XCTAssertEqual(harness.state.todaySegments.count, 2)
        XCTAssertEqual(harness.state.todaySegments[0].id, segment.id)
        XCTAssertEqual(harness.state.todaySegments[0].end, start.addingTimeInterval(30))
        XCTAssertEqual(right?.start, start.addingTimeInterval(30))
        XCTAssertEqual(right?.end, start.addingTimeInterval(80))
        XCTAssertEqual(harness.store.upsertedSegments.map(\.id), harness.state.todaySegments.map(\.id))
    }

    func testMergesSelectedSegmentWithNeighborAndDeletesNeighbor() {
        let harness = AppHarness()
        let start = Date(timeIntervalSince1970: 100)
        let previous = ActivitySegment(
            start: start,
            end: start.addingTimeInterval(30),
            state: .active,
            appName: "Safari",
            categoryID: CategoryID.browsing.rawValue
        )
        let selected = ActivitySegment(
            start: start.addingTimeInterval(30),
            end: start.addingTimeInterval(90),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue
        )
        harness.state.todaySegments = [previous, selected]

        let merged = harness.segmentEditingService.mergeSegment(
            segmentID: selected.id,
            withAdjacentSegmentID: previous.id
        )

        XCTAssertEqual(harness.state.todaySegments.count, 1)
        XCTAssertEqual(harness.state.todaySegments.first, merged)
        XCTAssertEqual(merged?.id, selected.id)
        XCTAssertEqual(merged?.start, previous.start)
        XCTAssertEqual(merged?.end, selected.end)
        XCTAssertEqual(harness.store.upsertedSegments.last?.id, selected.id)
        XCTAssertEqual(harness.store.deletedSegmentIDs, [previous.id])
    }
}

@MainActor
final class ProjectSessionServiceTests: XCTestCase {
    func testSwitchingProjectsClosesOldSessionAndStartsNewOne() {
        let harness = AppHarness()
        let first = ProjectContext(name: "Client A", defaultCategoryID: CategoryID.work.rawValue)
        let second = ProjectContext(name: "Client B", defaultCategoryID: CategoryID.work.rawValue)
        harness.state.contexts = [first, second]
        harness.state.currentContextID = first.id
        harness.state.todayProjectSessions = [
            ProjectSession(
                contextID: first.id,
                contextName: first.name,
                start: Date(timeIntervalSince1970: 100),
                createdAt: Date(timeIntervalSince1970: 100),
                updatedAt: Date(timeIntervalSince1970: 100)
            )
        ]

        harness.projectSessionService.setCurrentContext(id: second.id, now: Date(timeIntervalSince1970: 160))

        XCTAssertEqual(harness.state.currentContextID, second.id)
        XCTAssertEqual(harness.state.todayProjectSessions.count, 2)
        XCTAssertEqual(harness.state.todayProjectSessions[0].end, Date(timeIntervalSince1970: 160))
        XCTAssertEqual(harness.state.todayProjectSessions[1].contextID, second.id)
        XCTAssertNil(harness.state.todayProjectSessions[1].end)
        XCTAssertEqual(harness.contextPersistence.savedID, second.id)
        XCTAssertEqual(harness.store.upsertedProjectSessions.count, 2)
    }

    func testSelectingNoProjectClosesActiveSession() {
        let harness = AppHarness()
        let context = ProjectContext(name: "Client", defaultCategoryID: CategoryID.work.rawValue)
        harness.state.contexts = [context]
        harness.state.currentContextID = context.id
        harness.state.todayProjectSessions = [
            ProjectSession(
                contextID: context.id,
                contextName: context.name,
                start: Date(timeIntervalSince1970: 100),
                createdAt: Date(timeIntervalSince1970: 100),
                updatedAt: Date(timeIntervalSince1970: 100)
            )
        ]

        harness.projectSessionService.setCurrentContext(id: nil, now: Date(timeIntervalSince1970: 140))

        XCTAssertNil(harness.state.currentContextID)
        XCTAssertEqual(harness.state.todayProjectSessions.first?.end, Date(timeIntervalSince1970: 140))
        XCTAssertNil(harness.contextPersistence.savedID)
    }

    func testLoadStateUsesOpenSessionAsCurrentContext() {
        let harness = AppHarness()
        let context = ProjectContext(name: "Client", defaultCategoryID: CategoryID.work.rawValue)
        let session = ProjectSession(
            contextID: context.id,
            contextName: context.name,
            start: Date(timeIntervalSince1970: 100),
            createdAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 100)
        )
        harness.state.contexts = [context]
        harness.store.projectSessions = [session]

        harness.projectSessionService.loadState(now: Date(timeIntervalSince1970: 120))

        XCTAssertEqual(harness.state.currentContextID, context.id)
        XCTAssertEqual(harness.state.activeProjectSession, session)
        XCTAssertEqual(harness.contextPersistence.savedID, context.id)
    }
}

@MainActor
final class DashboardServiceTests: XCTestCase {
    func testPeriodChangeFetchesExpectedInterval() {
        let harness = AppHarness()
        let calendar = Self.calendar
        let service = DashboardService(store: harness.store, state: harness.state, calendar: calendar)
        let now = Self.date(year: 2026, month: 6, day: 23, hour: 12)

        service.setPeriod(.week, now: now)

        XCTAssertEqual(harness.state.dashboardPeriod, .week)
        XCTAssertEqual(harness.state.dashboardInterval.start, Self.date(year: 2026, month: 6, day: 22))
        XCTAssertEqual(harness.store.fetchedSegmentIntervals.last, harness.state.dashboardInterval)
        XCTAssertEqual(harness.store.fetchedProjectSessionIntervals.last, harness.state.dashboardInterval)
    }

    func testReloadUpdatesDashboardSegmentsAndProjectSessions() {
        let harness = AppHarness()
        let calendar = Self.calendar
        let service = DashboardService(store: harness.store, state: harness.state, calendar: calendar)
        let start = Self.date(year: 2026, month: 6, day: 23)
        let context = ProjectContext(name: "Daily Replica", defaultCategoryID: CategoryID.work.rawValue)
        let segment = ActivitySegment(
            start: start,
            end: start.addingTimeInterval(300),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue,
            contextID: context.id,
            contextName: context.name
        )
        let session = ProjectSession(
            contextID: context.id,
            contextName: context.name,
            start: start,
            end: start.addingTimeInterval(600)
        )
        harness.store.segments = [segment]
        harness.store.projectSessions = [session]

        service.reload(now: start.addingTimeInterval(120))

        XCTAssertEqual(harness.state.dashboardSegments, [segment])
        XCTAssertEqual(harness.state.dashboardProjectSessions, [session])
        XCTAssertEqual(harness.state.dashboardSummary.totalDuration, 300)
        XCTAssertEqual(harness.state.dashboardSummary.projectItems.first?.duration, 600)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        DateComponents(calendar: calendar, timeZone: TimeZone(secondsFromGMT: 0), year: year, month: month, day: day, hour: hour).date!
    }
}

@MainActor
final class PrivacyServiceTests: XCTestCase {
    func testJSONExportIncludesStoredData() throws {
        let harness = AppHarness()
        let context = ProjectContext(name: "Client", defaultCategoryID: CategoryID.work.rawValue)
        let segment = ActivitySegment(
            start: Date(timeIntervalSince1970: 10),
            end: Date(timeIntervalSince1970: 20),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue,
            contextID: context.id,
            contextName: context.name
        )
        harness.store.categories = CategoryID.builtInDefinitions
        harness.store.contexts = [context]
        harness.store.rules = [
            ClassificationRule(kind: .appBundleID, pattern: "com.apple.dt.Xcode", categoryID: CategoryID.work.rawValue)
        ]
        harness.store.segments = [segment]

        let json = String(decoding: try harness.privacyService.exportJSONData(), as: UTF8.self)

        XCTAssertTrue(json.contains("Client"))
        XCTAssertTrue(json.contains("Xcode"))
        XCTAssertTrue(json.contains("com.apple.dt.Xcode"))
    }

    func testClearActivityDataUpdatesStoreAndState() {
        let harness = AppHarness()
        let segment = ActivitySegment(
            start: Date(timeIntervalSince1970: 10),
            end: Date(timeIntervalSince1970: 20),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue
        )
        harness.store.segments = [segment]
        harness.state.todaySegments = [segment]
        harness.state.dashboardSegments = [segment]

        harness.privacyService.clearActivityData()

        XCTAssertTrue(harness.store.segments.isEmpty)
        XCTAssertTrue(harness.state.todaySegments.isEmpty)
        XCTAssertTrue(harness.state.dashboardSegments.isEmpty)
    }

    func testResetAllDataClearsUserCreatedState() {
        let harness = AppHarness()
        let context = ProjectContext(name: "Client", defaultCategoryID: CategoryID.work.rawValue)
        let rule = ClassificationRule(kind: .chromeHost, pattern: "github.com", categoryID: CategoryID.work.rawValue)
        harness.store.categories = CategoryID.builtInDefinitions + [CategoryDefinition(id: "reading", name: "Reading")]
        harness.store.contexts = [context]
        harness.store.rules = [rule]
        harness.state.categories = harness.store.categories
        harness.state.contexts = [context]
        harness.state.rules = [rule]
        harness.state.currentContextID = context.id
        harness.contextPersistence.saveCurrentContextID(context.id)

        harness.privacyService.resetAllData()

        XCTAssertEqual(harness.state.categories.map(\.id).sorted(), CategoryID.builtInDefinitions.map(\.id).sorted())
        XCTAssertTrue(harness.state.contexts.isEmpty)
        XCTAssertTrue(harness.state.rules.isEmpty)
        XCTAssertNil(harness.state.currentContextID)
        XCTAssertNil(harness.contextPersistence.savedID)
    }
}

@MainActor
final class TrackingServiceTests: XCTestCase {
    func testCaptureTickCreatesAndUpdatesClassifiedSegment() {
        let harness = AppHarness()
        let context = ProjectContext(name: "Daily Replica", defaultCategoryID: CategoryID.work.rawValue)
        harness.state.contexts = [context]
        harness.state.currentContextID = context.id
        harness.state.rules = [
            ClassificationRule(kind: .appBundleID, pattern: "com.apple.dt.Xcode", categoryID: CategoryID.work.rawValue)
        ]
        harness.sampler.sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 100),
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode"
        )

        harness.trackingService.captureTick(now: Date(timeIntervalSince1970: 100))
        harness.sampler.sample.timestamp = Date(timeIntervalSince1970: 160)
        harness.trackingService.captureTick(now: Date(timeIntervalSince1970: 160))

        XCTAssertEqual(harness.state.todaySegments.count, 1)
        XCTAssertEqual(harness.state.todaySegments.first?.categoryID, CategoryID.work.rawValue)
        XCTAssertEqual(harness.state.todaySegments.first?.contextName, "Daily Replica")
        XCTAssertEqual(harness.state.todaySegments.first?.end, Date(timeIntervalSince1970: 160))
        XCTAssertEqual(harness.store.upsertedSegments.last?.end, Date(timeIntervalSince1970: 160))
    }

    func testAppActivatedEventSamplesImmediatelyAndSplitsSegment() {
        let harness = AppHarness()
        harness.sampler.sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 100),
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode"
        )

        harness.trackingService.handleEvent(.heartbeat, now: Date(timeIntervalSince1970: 100))
        harness.sampler.sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 105),
            state: .active,
            appBundleID: "com.valvesoftware.steam",
            appName: "Steam"
        )
        harness.trackingService.handleEvent(.appActivated, now: Date(timeIntervalSince1970: 105))

        XCTAssertEqual(harness.state.todaySegments.count, 2)
        XCTAssertEqual(harness.state.todaySegments[0].appName, "Xcode")
        XCTAssertEqual(harness.state.todaySegments[1].appName, "Steam")
        XCTAssertEqual(harness.state.todaySegments[0].end, Date(timeIntervalSince1970: 105))
    }

    func testOwnAppSampleCreatesInactiveBoundary() {
        let harness = AppHarness()
        harness.sampler.sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 100),
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode"
        )

        harness.trackingService.handleEvent(.heartbeat, now: Date(timeIntervalSince1970: 100))
        harness.sampler.sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 105),
            state: .active,
            appBundleID: "local.daily-replica.app",
            appName: "Daily Replica"
        )
        harness.trackingService.handleEvent(.appActivated, now: Date(timeIntervalSince1970: 105))

        XCTAssertEqual(harness.state.todaySegments.count, 2)
        XCTAssertEqual(harness.state.todaySegments[0].appName, "Xcode")
        XCTAssertEqual(harness.state.todaySegments[1].state, .inactive)
        XCTAssertNil(harness.state.todaySegments[1].appBundleID)
        XCTAssertEqual(harness.state.todaySegments[1].categoryID, CategoryID.inactive.rawValue)
    }

    func testSessionResignEventCreatesInactiveBoundary() {
        let harness = AppHarness()
        harness.sampler.sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 100),
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode"
        )

        harness.trackingService.handleEvent(.heartbeat, now: Date(timeIntervalSince1970: 100))
        harness.trackingService.handleEvent(.sessionDidResignActive, now: Date(timeIntervalSince1970: 110))

        XCTAssertEqual(harness.state.todaySegments.count, 2)
        XCTAssertEqual(harness.state.todaySegments[1].state, .inactive)
        XCTAssertNil(harness.state.todaySegments[1].appName)
        XCTAssertNil(harness.state.todaySegments[1].contextID)
        XCTAssertEqual(harness.state.todaySegments[1].categoryID, CategoryID.inactive.rawValue)
        XCTAssertEqual(harness.store.upsertedSegments.last?.state, .inactive)
    }

    func testWakeEventAfterInactiveBoundaryDoesNotMergeIntoPreviousActiveSegment() {
        let harness = AppHarness()
        harness.sampler.sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 100),
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode"
        )

        harness.trackingService.handleEvent(.heartbeat, now: Date(timeIntervalSince1970: 100))
        harness.trackingService.handleEvent(.sessionDidResignActive, now: Date(timeIntervalSince1970: 110))
        harness.trackingService.handleEvent(.sessionDidBecomeActive, now: Date(timeIntervalSince1970: 120))

        XCTAssertEqual(harness.state.todaySegments.count, 3)
        XCTAssertEqual(harness.state.todaySegments.map(\.state), [.active, .inactive, .active])
        XCTAssertEqual(harness.state.todaySegments[2].appName, "Xcode")
        XCTAssertEqual(harness.state.todaySegments[2].start, Date(timeIntervalSince1970: 120))
    }

    func testStartAndStopTrackingManageEventObserver() {
        let harness = AppHarness()

        harness.trackingService.startTracking()
        XCTAssertTrue(harness.state.isTracking)
        XCTAssertTrue(harness.eventObserver.isStarted)
        XCTAssertNotNil(harness.eventObserver.onEvent)

        harness.trackingService.stopTracking()
        XCTAssertFalse(harness.state.isTracking)
        XCTAssertFalse(harness.eventObserver.isStarted)
        XCTAssertNil(harness.eventObserver.onEvent)
    }
}

@MainActor
final class PromptServiceTests: XCTestCase {
    func testUnclassifiedPromptShowsAndRecordsActivePrompt() {
        let harness = AppHarness(promptEngine: SmartPromptEngine(unclassifiedThreshold: 1, cooldown: 60))
        harness.state.todaySegments = [
            ActivitySegment(
                start: Date(timeIntervalSince1970: 100),
                end: Date(timeIntervalSince1970: 105),
                state: .active,
                appBundleID: "com.example.App",
                appName: "Example",
                categoryID: CategoryID.unclassified.rawValue
            )
        ]

        harness.promptService.showPromptIfNeeded(now: Date(timeIntervalSince1970: 105))

        XCTAssertEqual(harness.state.activePrompt?.kind, .unclassifiedActivity)
        XCTAssertEqual(harness.promptPresenter.shownPrompt?.appBundleID, "com.example.App")
    }

    func testCreateRuleFromPromptStoresRuleAndDismisses() {
        let harness = AppHarness()
        let prompt = SmartPrompt(
            kind: .unclassifiedActivity,
            key: "unclassified:github.com",
            title: "Classify GitHub?",
            message: "Message",
            urlHost: "github.com",
            currentCategoryID: CategoryID.unclassified.rawValue
        )
        harness.state.activePrompt = prompt

        harness.promptService.createRule(from: prompt, categoryID: CategoryID.work.rawValue)

        XCTAssertEqual(harness.store.rules.first?.kind, .chromeHost)
        XCTAssertEqual(harness.store.rules.first?.pattern, "github.com")
        XCTAssertNil(harness.state.activePrompt)
        XCTAssertTrue(harness.promptPresenter.didDismiss)
    }
}

@MainActor
final class ViewModelTests: XCTestCase {
    func testMenuViewModelTogglesTrackingService() {
        let harness = AppHarness()
        let context = ProjectContext(name: "Daily Replica", defaultCategoryID: CategoryID.work.rawValue)
        harness.state.contexts = [context]
        harness.state.currentContextID = context.id
        let viewModel = MenuBarViewModel(
            state: harness.state,
            trackingService: harness.trackingService,
            libraryService: harness.libraryService,
            projectSessionService: harness.projectSessionService
        )

        viewModel.toggleTracking()
        XCTAssertTrue(harness.state.isTracking)
        XCTAssertEqual(harness.state.activeProjectSession?.contextID, context.id)
        viewModel.toggleTracking()
        XCTAssertFalse(harness.state.isTracking)
        XCTAssertNotNil(harness.state.todayProjectSessions.first?.end)
    }

    func testTodayViewModelFallsBackWhenSelectedSegmentDisappears() {
        let harness = AppHarness()
        let first = ActivitySegment(
            start: Date(timeIntervalSince1970: 10),
            end: Date(timeIntervalSince1970: 20),
            state: .active,
            appName: "First",
            categoryID: CategoryID.work.rawValue
        )
        let second = ActivitySegment(
            start: Date(timeIntervalSince1970: 20),
            end: Date(timeIntervalSince1970: 30),
            state: .active,
            appName: "Second",
            categoryID: CategoryID.personal.rawValue
        )
        harness.state.todaySegments = [first, second]
        let viewModel = TodayViewModel(
            state: harness.state,
            libraryService: harness.libraryService,
            segmentEditingService: harness.segmentEditingService,
            dashboardService: harness.dashboardService
        )

        viewModel.selectedSegmentID = first.id
        harness.state.todaySegments = [second]
        viewModel.selectLatestIfNeeded()

        XCTAssertEqual(viewModel.selectedSegment?.id, second.id)
    }

    func testTodayViewModelSplitSelectsRightHalf() {
        let harness = AppHarness()
        let start = Date(timeIntervalSince1970: 100)
        let segment = ActivitySegment(
            start: start,
            end: start.addingTimeInterval(100),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue
        )
        harness.state.todaySegments = [segment]
        let viewModel = TodayViewModel(
            state: harness.state,
            libraryService: harness.libraryService,
            segmentEditingService: harness.segmentEditingService,
            dashboardService: harness.dashboardService
        )
        viewModel.selectSegment(id: segment.id)
        viewModel.splitTime = start.addingTimeInterval(40)

        viewModel.splitSelectedSegment()

        XCTAssertEqual(harness.state.todaySegments.count, 2)
        XCTAssertEqual(viewModel.selectedSegmentID, harness.state.todaySegments[1].id)
        XCTAssertEqual(viewModel.selectedSegment?.start, start.addingTimeInterval(40))
    }

    func testTodayViewModelMergePreservesSelectedSegment() {
        let harness = AppHarness()
        let start = Date(timeIntervalSince1970: 100)
        let previous = ActivitySegment(
            start: start,
            end: start.addingTimeInterval(40),
            state: .active,
            appName: "Safari",
            categoryID: CategoryID.browsing.rawValue
        )
        let selected = ActivitySegment(
            start: start.addingTimeInterval(40),
            end: start.addingTimeInterval(100),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue
        )
        harness.state.todaySegments = [previous, selected]
        let viewModel = TodayViewModel(
            state: harness.state,
            libraryService: harness.libraryService,
            segmentEditingService: harness.segmentEditingService,
            dashboardService: harness.dashboardService
        )
        viewModel.selectSegment(id: selected.id)

        viewModel.mergeSelectedSegmentWithPrevious()

        XCTAssertEqual(harness.state.todaySegments.count, 1)
        XCTAssertEqual(viewModel.selectedSegmentID, selected.id)
        XCTAssertEqual(viewModel.selectedSegment?.start, previous.start)
        XCTAssertEqual(viewModel.selectedSegment?.end, selected.end)
    }

    func testTodayViewModelDeleteSelectedSegmentMarksItInactive() {
        let harness = AppHarness()
        let segment = ActivitySegment(
            start: Date(timeIntervalSince1970: 100),
            end: Date(timeIntervalSince1970: 160),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue
        )
        harness.state.todaySegments = [segment]
        let viewModel = TodayViewModel(
            state: harness.state,
            libraryService: harness.libraryService,
            segmentEditingService: harness.segmentEditingService,
            dashboardService: harness.dashboardService
        )
        viewModel.selectSegment(id: segment.id)

        viewModel.deleteSelectedSegment()

        XCTAssertEqual(viewModel.selectedSegmentID, segment.id)
        XCTAssertEqual(viewModel.selectedSegment?.state, .inactive)
        XCTAssertEqual(viewModel.selectedSegment?.categoryID, CategoryID.inactive.rawValue)
        XCTAssertNil(viewModel.selectedSegment?.appName)
    }

    func testMenuViewModelCreateProjectStartsProjectSession() {
        let harness = AppHarness()
        let viewModel = MenuBarViewModel(
            state: harness.state,
            trackingService: harness.trackingService,
            libraryService: harness.libraryService,
            projectSessionService: harness.projectSessionService
        )
        viewModel.newProjectName = "Client Launch"
        viewModel.newProjectCategoryID = CategoryID.work.rawValue

        viewModel.createProject()

        let context = harness.state.contexts.first { $0.name == "Client Launch" }
        XCTAssertEqual(harness.state.currentContextID, context?.id)
        XCTAssertEqual(harness.state.activeProjectSession?.contextID, context?.id)
        XCTAssertEqual(harness.store.upsertedProjectSessions.last?.contextName, "Client Launch")
    }

    func testTodayViewModelCreateProjectAndUseDoesNotSwitchActiveSession() {
        let harness = AppHarness()
        let current = ProjectContext(name: "Current", defaultCategoryID: CategoryID.work.rawValue)
        let segment = ActivitySegment(
            start: Date(timeIntervalSince1970: 10),
            end: Date(timeIntervalSince1970: 20),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue
        )
        harness.state.contexts = [current]
        harness.state.currentContextID = current.id
        harness.state.todaySegments = [segment]
        let viewModel = TodayViewModel(
            state: harness.state,
            libraryService: harness.libraryService,
            segmentEditingService: harness.segmentEditingService,
            dashboardService: harness.dashboardService
        )
        viewModel.newProjectName = "Correction Project"
        viewModel.newProjectCategoryID = CategoryID.work.rawValue

        viewModel.createProjectAndUse(segmentID: segment.id)

        XCTAssertEqual(harness.state.currentContextID, current.id)
        XCTAssertEqual(harness.state.todaySegments.first?.contextName, "Correction Project")
    }

    func testTodayViewModelDashboardPeriodDelegatesToService() {
        let harness = AppHarness()
        let viewModel = TodayViewModel(
            state: harness.state,
            libraryService: harness.libraryService,
            segmentEditingService: harness.segmentEditingService,
            dashboardService: harness.dashboardService
        )

        viewModel.setDashboardPeriod(.month)

        XCTAssertEqual(viewModel.dashboardPeriod, .month)
        XCTAssertNotNil(harness.store.fetchedSegmentIntervals.last)
        XCTAssertEqual(harness.store.fetchedSegmentIntervals.last, harness.state.dashboardInterval)
    }

    func testTodayViewModelExposesSortedDashboardItems() {
        let harness = AppHarness()
        let start = DateInterval.day(containing: Date()).start
        harness.state.dashboardInterval = DateInterval(start: start, duration: 24 * 60 * 60)
        harness.state.dashboardSegments = [
            ActivitySegment(
                start: start,
                end: start.addingTimeInterval(120),
                state: .active,
                appBundleID: "com.apple.Safari",
                appName: "Safari",
                categoryID: CategoryID.browsing.rawValue
            ),
            ActivitySegment(
                start: start.addingTimeInterval(120),
                end: start.addingTimeInterval(420),
                state: .active,
                appBundleID: "com.apple.dt.Xcode",
                appName: "Xcode",
                categoryID: CategoryID.work.rawValue
            )
        ]
        let viewModel = TodayViewModel(
            state: harness.state,
            libraryService: harness.libraryService,
            segmentEditingService: harness.segmentEditingService,
            dashboardService: harness.dashboardService
        )

        XCTAssertEqual(viewModel.dashboardAppItems.map(\.title), ["Xcode", "Safari"])
        XCTAssertEqual(viewModel.dashboardCategoryItems.first?.id, CategoryID.work.rawValue)
    }

    func testSettingsViewModelCreatesCategoryAndClearsField() {
        let harness = AppHarness()
        let viewModel = SettingsViewModel(
            state: harness.state,
            libraryService: harness.libraryService,
            privacyService: harness.privacyService
        )
        viewModel.categoryName = "Reading"

        viewModel.createCategory()

        XCTAssertEqual(harness.state.categories.map(\.name), ["Reading"])
        XCTAssertEqual(viewModel.categoryName, "")
    }

    func testSettingsViewModelExposesRuleSuggestionsFromManualCorrections() {
        let harness = AppHarness()
        harness.state.todaySegments = [
            correctedAppSegment(start: 10, end: 70),
            correctedAppSegment(start: 70, end: 130)
        ]
        let viewModel = SettingsViewModel(
            state: harness.state,
            libraryService: harness.libraryService,
            privacyService: harness.privacyService
        )

        XCTAssertEqual(viewModel.ruleSuggestions.count, 1)
        XCTAssertEqual(viewModel.ruleSuggestions.first?.pattern, "com.example.Editor")
        XCTAssertEqual(viewModel.ruleSuggestions.first?.suggestedCategoryID, CategoryID.work.rawValue)
    }

    func testSettingsViewModelAcceptsSuggestionAndRemovesIt() {
        let harness = AppHarness()
        harness.state.todaySegments = [
            correctedAppSegment(start: 10, end: 70),
            correctedAppSegment(start: 70, end: 130)
        ]
        let viewModel = SettingsViewModel(
            state: harness.state,
            libraryService: harness.libraryService,
            privacyService: harness.privacyService
        )

        guard let suggestion = viewModel.ruleSuggestions.first else {
            return XCTFail("Expected a rule suggestion")
        }
        viewModel.acceptRuleSuggestion(suggestion)

        XCTAssertEqual(harness.state.rules.first?.kind, .appBundleID)
        XCTAssertEqual(harness.state.rules.first?.pattern, "com.example.Editor")
        XCTAssertTrue(viewModel.ruleSuggestions.isEmpty)
    }

    func testSettingsViewModelBulkClassifiesWithSelectedCategory() {
        let harness = AppHarness()
        harness.state.todaySegments = [
            ActivitySegment(
                start: Date(timeIntervalSince1970: 10),
                end: Date(timeIntervalSince1970: 70),
                state: .active,
                appBundleID: "com.example.Editor",
                appName: "Editor",
                categoryID: CategoryID.unclassified.rawValue
            )
        ]
        harness.store.segments = harness.state.todaySegments
        let viewModel = SettingsViewModel(
            state: harness.state,
            libraryService: harness.libraryService,
            privacyService: harness.privacyService
        )
        viewModel.bulkRuleCategoryID = CategoryID.personal.rawValue

        guard let candidate = viewModel.unclassifiedCandidates.first else {
            return XCTFail("Expected an uncategorized candidate")
        }
        let changed = viewModel.classifyUncategorized(candidate)

        XCTAssertEqual(changed, 1)
        XCTAssertEqual(harness.state.rules.first?.categoryID, CategoryID.personal.rawValue)
        XCTAssertEqual(harness.state.todaySegments.first?.categoryID, CategoryID.personal.rawValue)
    }

    func testSettingsViewModelExportsTextAndClearsActivity() {
        let harness = AppHarness()
        let segment = ActivitySegment(
            start: Date(timeIntervalSince1970: 10),
            end: Date(timeIntervalSince1970: 20),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue
        )
        harness.store.segments = [segment]
        harness.state.todaySegments = [segment]
        let viewModel = SettingsViewModel(
            state: harness.state,
            libraryService: harness.libraryService,
            privacyService: harness.privacyService
        )

        XCTAssertTrue(viewModel.exportJSONText()?.contains("Xcode") == true)
        XCTAssertTrue(viewModel.exportSegmentsCSVText()?.contains("Xcode") == true)

        viewModel.clearActivityData()

        XCTAssertTrue(harness.state.todaySegments.isEmpty)
        XCTAssertTrue(harness.store.segments.isEmpty)
    }

    func testMenuViewModelCapturesNewSegmentWhenProjectChangesDuringTracking() {
        let harness = AppHarness()
        let firstContext = ProjectContext(name: "Client A", defaultCategoryID: CategoryID.work.rawValue)
        let secondContext = ProjectContext(name: "Client B", defaultCategoryID: CategoryID.work.rawValue)
        harness.state.contexts = [firstContext, secondContext]
        harness.state.currentContextID = firstContext.id
        harness.state.isTracking = true
        harness.sampler.sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 100),
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode"
        )
        harness.trackingService.captureTick(now: Date(timeIntervalSince1970: 100))
        let viewModel = MenuBarViewModel(
            state: harness.state,
            trackingService: harness.trackingService,
            libraryService: harness.libraryService,
            projectSessionService: harness.projectSessionService
        )

        viewModel.setCurrentContext(selection: secondContext.id.uuidString)

        XCTAssertEqual(harness.state.todaySegments.count, 2)
        XCTAssertEqual(harness.state.todaySegments[0].contextID, firstContext.id)
        XCTAssertEqual(harness.state.todaySegments[1].contextID, secondContext.id)
        XCTAssertEqual(harness.store.upsertedSegments.last?.contextID, secondContext.id)
    }

    private func correctedAppSegment(start: TimeInterval, end: TimeInterval) -> ActivitySegment {
        ActivitySegment(
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: end),
            state: .active,
            appBundleID: "com.example.Editor",
            appName: "Editor",
            categoryID: CategoryID.work.rawValue,
            manualCategoryID: CategoryID.work.rawValue
        )
    }
}

@MainActor
private final class AppHarness {
    let state = AppState()
    let store = InMemoryActivityStore()
    let contextPersistence = TestCurrentContextPersistence()
    let permissionChecker = TestPermissionChecker()
    let sampler = TestSampler()
    let eventObserver = TestActivityEventObserver()
    let promptPresenter = TestPromptPresenter()
    let libraryService: LibraryService
    let segmentEditingService: SegmentEditingService
    let projectSessionService: ProjectSessionService
    let dashboardService: DashboardService
    let privacyService: PrivacyService
    let promptService: PromptService
    let trackingService: TrackingService

    init(promptEngine: SmartPromptEngine = SmartPromptEngine(mismatchThreshold: 10_000, unclassifiedThreshold: 10_000)) {
        libraryService = LibraryService(
            store: store,
            state: state,
            contextPersistence: contextPersistence,
            permissionChecker: permissionChecker
        )
        segmentEditingService = SegmentEditingService(store: store, state: state)
        projectSessionService = ProjectSessionService(
            store: store,
            state: state,
            contextPersistence: contextPersistence
        )
        dashboardService = DashboardService(store: store, state: state)
        privacyService = PrivacyService(
            store: store,
            state: state,
            contextPersistence: contextPersistence
        )
        promptService = PromptService(state: state, libraryService: libraryService, promptEngine: promptEngine)
        trackingService = TrackingService(
            store: store,
            state: state,
            sampler: sampler,
            permissionChecker: permissionChecker,
            promptService: promptService,
            eventObserver: eventObserver,
            heartbeatInterval: 10_000
        )
        promptService.presenter = promptPresenter
        state.categories = []
    }
}

private final class InMemoryActivityStore: ActivityStore {
    var categories: [CategoryDefinition] = []
    var contexts: [ProjectContext] = []
    var rules: [ClassificationRule] = []
    var segments: [ActivitySegment] = []
    var upsertedSegments: [ActivitySegment] = []
    var deletedSegmentIDs: [UUID] = []
    var projectSessions: [ProjectSession] = []
    var upsertedProjectSessions: [ProjectSession] = []
    var fetchedSegmentIntervals: [DateInterval] = []
    var fetchedProjectSessionIntervals: [DateInterval] = []

    func fetchCategories() throws -> [CategoryDefinition] {
        categories
    }

    func upsertCategory(_ category: CategoryDefinition) throws {
        categories.removeAll { $0.id == category.id }
        categories.append(category)
    }

    func fetchContexts(includeArchived: Bool) throws -> [ProjectContext] {
        includeArchived ? contexts : contexts.filter { !$0.isArchived }
    }

    func upsertContext(_ context: ProjectContext) throws {
        contexts.removeAll { $0.id == context.id }
        contexts.append(context)
    }

    func fetchRules() throws -> [ClassificationRule] {
        rules
    }

    func upsertRule(_ rule: ClassificationRule) throws {
        rules.removeAll { $0.id == rule.id }
        rules.append(rule)
    }

    func deleteRule(id: UUID) throws {
        rules.removeAll { $0.id == id }
    }

    func upsertSegment(_ segment: ActivitySegment) throws {
        segments.removeAll { $0.id == segment.id }
        segments.append(segment)
        upsertedSegments.append(segment)
    }

    func deleteSegment(id: UUID) throws {
        segments.removeAll { $0.id == id }
        deletedSegmentIDs.append(id)
    }

    func fetchSegments(in interval: DateInterval) throws -> [ActivitySegment] {
        fetchedSegmentIntervals.append(interval)
        return segments.filter { $0.start < interval.end && $0.end >= interval.start }
    }

    func fetchProjectSessions(in interval: DateInterval) throws -> [ProjectSession] {
        fetchedProjectSessionIntervals.append(interval)
        return projectSessions.filter { $0.start < interval.end && ($0.end ?? .distantFuture) >= interval.start }
    }

    func fetchOpenProjectSession() throws -> ProjectSession? {
        projectSessions.last { $0.end == nil }
    }

    func upsertProjectSession(_ session: ProjectSession) throws {
        projectSessions.removeAll { $0.id == session.id }
        projectSessions.append(session)
        upsertedProjectSessions.append(session)
    }

    func deleteAllActivityData() throws {
        segments.removeAll()
        projectSessions.removeAll()
    }

    func deleteAllUserData() throws {
        categories = categories.filter(\.isBuiltIn)
        contexts.removeAll()
        rules.removeAll()
        try deleteAllActivityData()
    }
}

private final class TestCurrentContextPersistence: CurrentContextPersisting {
    var savedID: UUID?

    func loadCurrentContextID() -> UUID? {
        savedID
    }

    func saveCurrentContextID(_ id: UUID?) {
        savedID = id
    }
}

private struct TestPermissionChecker: PermissionChecking {
    var trusted = true

    func isAccessibilityTrusted(prompt: Bool) -> Bool {
        trusted
    }
}

private final class TestSampler: ActivitySampling {
    var sample = FocusSample(
        timestamp: Date(timeIntervalSince1970: 0),
        state: .active,
        appBundleID: "com.example.App",
        appName: "Example"
    )

    func sample(now: Date, accessibilityTrusted: Bool) -> FocusSample {
        var sample = sample
        sample.timestamp = now
        return sample
    }
}

@MainActor
private final class TestActivityEventObserver: ActivityEventObserving {
    var onEvent: ((TrackingEvent) -> Void)?
    var isStarted = false

    func start() {
        isStarted = true
    }

    func stop() {
        isStarted = false
    }
}

@MainActor
private final class TestPromptPresenter: PromptPresenting {
    var shownPrompt: SmartPrompt?
    var didDismiss = false

    func showPrompt(_ prompt: SmartPrompt) {
        shownPrompt = prompt
    }

    func dismissPrompt() {
        didDismiss = true
    }
}
