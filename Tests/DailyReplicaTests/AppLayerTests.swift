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
        let viewModel = MenuBarViewModel(
            state: harness.state,
            trackingService: harness.trackingService,
            libraryService: harness.libraryService
        )

        viewModel.toggleTracking()
        XCTAssertTrue(harness.state.isTracking)
        viewModel.toggleTracking()
        XCTAssertFalse(harness.state.isTracking)
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
            segmentEditingService: harness.segmentEditingService
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
            segmentEditingService: harness.segmentEditingService
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
            segmentEditingService: harness.segmentEditingService
        )
        viewModel.selectSegment(id: selected.id)

        viewModel.mergeSelectedSegmentWithPrevious()

        XCTAssertEqual(harness.state.todaySegments.count, 1)
        XCTAssertEqual(viewModel.selectedSegmentID, selected.id)
        XCTAssertEqual(viewModel.selectedSegment?.start, previous.start)
        XCTAssertEqual(viewModel.selectedSegment?.end, selected.end)
    }

    func testSettingsViewModelCreatesCategoryAndClearsField() {
        let harness = AppHarness()
        let viewModel = SettingsViewModel(state: harness.state, libraryService: harness.libraryService)
        viewModel.categoryName = "Reading"

        viewModel.createCategory()

        XCTAssertEqual(harness.state.categories.map(\.name), ["Reading"])
        XCTAssertEqual(viewModel.categoryName, "")
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
            libraryService: harness.libraryService
        )

        viewModel.setCurrentContext(selection: secondContext.id.uuidString)

        XCTAssertEqual(harness.state.todaySegments.count, 2)
        XCTAssertEqual(harness.state.todaySegments[0].contextID, firstContext.id)
        XCTAssertEqual(harness.state.todaySegments[1].contextID, secondContext.id)
        XCTAssertEqual(harness.store.upsertedSegments.last?.contextID, secondContext.id)
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
        segments.filter { $0.start < interval.end && $0.end >= interval.start }
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
