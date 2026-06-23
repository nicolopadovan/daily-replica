#if DEBUG
import DailyReplicaCore
import Foundation

@MainActor
enum PreviewFactory {
    static func menuBarViewModel(showingCreateProject: Bool = false) -> MenuBarViewModel {
        let fixture = makeFixture()
        let viewModel = MenuBarViewModel(
            state: fixture.state,
            trackingService: fixture.trackingService,
            libraryService: fixture.libraryService,
            projectSessionService: fixture.projectSessionService
        )
        viewModel.coordinator = fixture.coordinator
        viewModel.isCreatingProject = showingCreateProject
        viewModel.newProjectName = showingCreateProject ? "Launch planning" : ""
        return viewModel
    }

    static func todayViewModel() -> TodayViewModel {
        let fixture = makeFixture()
        let viewModel = TodayViewModel(
            state: fixture.state,
            libraryService: fixture.libraryService,
            segmentEditingService: fixture.segmentEditingService,
            dashboardService: fixture.dashboardService
        )
        viewModel.coordinator = fixture.coordinator
        viewModel.selectedSegmentID = fixture.state.todaySegments.last?.id
        return viewModel
    }

    static func settingsViewModel(section: SettingsSection = .categories) -> SettingsViewModel {
        let fixture = makeFixture()
        let viewModel = SettingsViewModel(state: fixture.state, libraryService: fixture.libraryService)
        viewModel.selectedSection = section
        return viewModel
    }

    static func smartPromptViewModel(kind: SmartPromptKind = .unclassifiedActivity) -> SmartPromptViewModel {
        let fixture = makeFixture()
        let prompt = SmartPrompt(
            kind: kind,
            key: kind == .unclassifiedActivity ? "unclassified:github.com" : "mismatch:context:github.com",
            title: kind == .unclassifiedActivity ? "Classify GitHub?" : "Still working on Daily Replica?",
            message: kind == .unclassifiedActivity
                ? "Daily Replica has seen this activity for at least 2 minutes without a category."
                : "Xcode is categorized as Work, while the current context defaults to Personal.",
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode",
            urlHost: "github.com",
            currentCategoryID: CategoryID.unclassified.rawValue,
            suggestedCategoryID: CategoryID.work.rawValue
        )
        return SmartPromptViewModel(
            prompt: prompt,
            state: fixture.state,
            promptService: fixture.promptService,
            coordinator: fixture.coordinator
        )
    }

    static func segment() -> ActivitySegment {
        sampleSegments().last!
    }

    static func ribbonEntries() -> [ActivityRibbonEntry] {
        ActivityDayPresenter.ribbonEntries(for: sampleSegments(), in: DateInterval.day(containing: Date()))
    }

    private static func makeFixture() -> PreviewFixture {
        let state = AppState()
        let context = ProjectContext(name: "Daily Replica", defaultCategoryID: CategoryID.work.rawValue)
        let store = PreviewActivityStore()
        let contextPersistence = PreviewCurrentContextPersistence()
        let permissionChecker = PreviewPermissionChecker()
        let libraryService = LibraryService(
            store: store,
            state: state,
            contextPersistence: contextPersistence,
            permissionChecker: permissionChecker
        )
        let segmentEditingService = SegmentEditingService(store: store, state: state)
        let projectSessionService = ProjectSessionService(
            store: store,
            state: state,
            contextPersistence: contextPersistence
        )
        let dashboardService = DashboardService(store: store, state: state)
        let promptService = PromptService(state: state, libraryService: libraryService)
        let trackingService = TrackingService(
            store: store,
            state: state,
            sampler: PreviewSampler(),
            permissionChecker: permissionChecker,
            promptService: promptService
        )

        state.isTracking = true
        state.categories = CategoryID.builtInDefinitions
        state.contexts = [
            context,
            ProjectContext(name: "Client Website", defaultCategoryID: CategoryID.work.rawValue),
            ProjectContext(name: "Personal Admin", defaultCategoryID: CategoryID.personal.rawValue)
        ]
        state.currentContextID = context.id
        state.todayProjectSessions = [
            ProjectSession(
                contextID: context.id,
                contextName: context.name,
                start: Date().addingTimeInterval(-2_400)
            )
        ]
        state.rules = [
            ClassificationRule(kind: .appBundleID, pattern: "com.apple.dt.Xcode", categoryID: CategoryID.work.rawValue),
            ClassificationRule(kind: .chromeHost, pattern: "github.com", categoryID: CategoryID.work.rawValue)
        ]
        state.todaySegments = sampleSegments(context: context)
        state.dashboardSegments = state.todaySegments
        state.dashboardProjectSessions = state.todayProjectSessions
        store.segments = state.todaySegments
        store.projectSessions = state.todayProjectSessions
        state.lastSampleDescription = "Xcode · Work · github.com"
        state.accessibilityTrusted = false

        return PreviewFixture(
            state: state,
            libraryService: libraryService,
            segmentEditingService: segmentEditingService,
            projectSessionService: projectSessionService,
            dashboardService: dashboardService,
            promptService: promptService,
            trackingService: trackingService,
            coordinator: PreviewCoordinator()
        )
    }

    private static func sampleSegments(context: ProjectContext? = nil) -> [ActivitySegment] {
        let day = DateInterval.day(containing: Date())
        let context = context ?? ProjectContext(name: "Daily Replica", defaultCategoryID: CategoryID.work.rawValue)
        return [
            ActivitySegment(
                start: day.start.addingTimeInterval(9 * 60 * 60),
                end: day.start.addingTimeInterval(10 * 60 * 60 + 20 * 60),
                state: .active,
                appBundleID: "com.apple.dt.Xcode",
                appName: "Xcode",
                windowTitle: "Daily Replica",
                urlHost: "github.com",
                categoryID: CategoryID.work.rawValue,
                contextID: context.id,
                contextName: context.name
            ),
            ActivitySegment(
                start: day.start.addingTimeInterval(10 * 60 * 60 + 20 * 60),
                end: day.start.addingTimeInterval(10 * 60 * 60 + 45 * 60),
                state: .inactive,
                appName: "Inactive",
                categoryID: CategoryID.inactive.rawValue
            ),
            ActivitySegment(
                start: day.start.addingTimeInterval(10 * 60 * 60 + 45 * 60),
                end: day.start.addingTimeInterval(11 * 60 * 60 + 30 * 60),
                state: .active,
                appBundleID: "com.google.Chrome",
                appName: "Google Chrome",
                windowTitle: "GitHub Pull Request",
                urlString: "https://github.com/nicolopadovan/daily-replica",
                urlHost: "github.com",
                categoryID: CategoryID.work.rawValue,
                contextID: context.id,
                contextName: context.name,
                manualCategoryID: CategoryID.work.rawValue
            ),
            ActivitySegment(
                start: day.start.addingTimeInterval(11 * 60 * 60 + 30 * 60),
                end: day.start.addingTimeInterval(11 * 60 * 60 + 45 * 60),
                state: .active,
                appBundleID: "com.tinyspeck.slackmacgap",
                appName: "Slack",
                categoryID: CategoryID.communication.rawValue,
                manualCategoryID: CategoryID.communication.rawValue
            ),
            ActivitySegment(
                start: day.start.addingTimeInterval(11 * 60 * 60 + 45 * 60),
                end: day.start.addingTimeInterval(12 * 60 * 60),
                state: .active,
                appBundleID: "com.tinyspeck.slackmacgap",
                appName: "Slack",
                categoryID: CategoryID.communication.rawValue,
                manualCategoryID: CategoryID.communication.rawValue
            ),
            ActivitySegment(
                start: day.start.addingTimeInterval(12 * 60 * 60),
                end: day.start.addingTimeInterval(12 * 60 * 60 + 20 * 60),
                state: .active,
                appBundleID: "md.obsidian",
                appName: "Obsidian",
                categoryID: CategoryID.unclassified.rawValue
            )
        ]
    }
}

@MainActor
private struct PreviewFixture {
    let state: AppState
    let libraryService: LibraryService
    let segmentEditingService: SegmentEditingService
    let projectSessionService: ProjectSessionService
    let dashboardService: DashboardService
    let promptService: PromptService
    let trackingService: TrackingService
    let coordinator: AppCoordinating
}

private final class PreviewActivityStore: ActivityStore {
    var categories = CategoryID.builtInDefinitions
    var contexts: [ProjectContext] = []
    var rules: [ClassificationRule] = []
    var segments: [ActivitySegment] = []
    var projectSessions: [ProjectSession] = []

    func fetchCategories() throws -> [CategoryDefinition] { categories }
    func upsertCategory(_ category: CategoryDefinition) throws { categories.append(category) }
    func fetchContexts(includeArchived: Bool) throws -> [ProjectContext] { contexts }
    func upsertContext(_ context: ProjectContext) throws { contexts.append(context) }
    func fetchRules() throws -> [ClassificationRule] { rules }
    func upsertRule(_ rule: ClassificationRule) throws { rules.append(rule) }
    func deleteRule(id: UUID) throws { rules.removeAll { $0.id == id } }
    func upsertSegment(_ segment: ActivitySegment) throws { segments.append(segment) }
    func deleteSegment(id: UUID) throws { segments.removeAll { $0.id == id } }
    func fetchSegments(in interval: DateInterval) throws -> [ActivitySegment] { segments }
    func fetchProjectSessions(in interval: DateInterval) throws -> [ProjectSession] { projectSessions }
    func fetchOpenProjectSession() throws -> ProjectSession? { projectSessions.last { $0.end == nil } }
    func upsertProjectSession(_ session: ProjectSession) throws { projectSessions.append(session) }
}

private struct PreviewCurrentContextPersistence: CurrentContextPersisting {
    func loadCurrentContextID() -> UUID? { nil }
    func saveCurrentContextID(_ id: UUID?) {}
}

private struct PreviewPermissionChecker: PermissionChecking {
    func isAccessibilityTrusted(prompt: Bool) -> Bool { false }
}

private struct PreviewSampler: ActivitySampling {
    func sample(now: Date, accessibilityTrusted: Bool) -> FocusSample {
        FocusSample(
            timestamp: now,
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode",
            windowTitle: "Daily Replica",
            urlString: "https://github.com/nicolopadovan/daily-replica"
        )
    }
}

@MainActor
private final class PreviewCoordinator: AppCoordinating {
    func openToday() {}
    func openSettings() {}
    func quit() {}
    func showPrompt(_ prompt: SmartPrompt) {}
    func dismissPrompt() {}
}
#endif
