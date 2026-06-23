import AppKit
import Combine
import DailyReplicaCore
import Foundation
import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case today
    case analytics
    case contexts
    case categories
    case rules
    case permissions
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .analytics: "Analytics"
        case .contexts: "Projects"
        case .categories: "Categories"
        case .rules: "Auto-sort"
        case .permissions: "Permissions"
        case .updates: "Updates"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "chart.bar.xaxis"
        case .analytics: "chart.bar.doc.horizontal"
        case .contexts: "folder.fill"
        case .categories: "square.grid.2x2.fill"
        case .rules: "tag.fill"
        case .permissions: "lock.shield.fill"
        case .updates: "arrow.triangle.2.circlepath"
        }
    }

    var settingsSection: SettingsSection? {
        switch self {
        case .today: nil
        case .analytics: nil
        case .contexts: .contexts
        case .categories: .categories
        case .rules: .rules
        case .permissions: .permissions
        case .updates: .updates
        }
    }
}

@MainActor
final class AppCoordinator: ObservableObject, AppCoordinating {
    private static let hasSeenDefaultAutoSortPromptKey = "hasSeenDefaultAutoSortPrompt"

    @Published var selectedSection = AppSection.today

    let state: AppState
    let menuBarViewModel: MenuBarViewModel
    let todayViewModel: TodayViewModel
    let settingsViewModel: SettingsViewModel
    let analyticsViewModel: AnalyticsViewModel

    private let libraryService: LibraryService
    private let projectSessionService: ProjectSessionService
    private let trackingService: TrackingService
    private let dashboardService: DashboardService
    private let analyticsService: AnalyticsService
    private let privacyService: PrivacyService
    private let updateService: UpdateService
    private let promptService: PromptService
    private let promptPanelCoordinator: PromptPanelCoordinator
    private var openWindow: ((String) -> Void)?
    private var stateCancellable: AnyCancellable?

    init() {
        do {
            let state = AppState()
            let store = try SQLiteActivityStore(path: Self.defaultStorePath())
            let contextPersistence = UserDefaultsCurrentContextStore()
            let permissionChecker = AccessibilityPermissionChecker()
            let libraryService = LibraryService(
                store: store,
                state: state,
                contextPersistence: contextPersistence,
                permissionChecker: permissionChecker
            )
            let projectSessionService = ProjectSessionService(
                store: store,
                state: state,
                contextPersistence: contextPersistence
            )
            let dashboardService = DashboardService(store: store, state: state)
            let analyticsService = AnalyticsService(store: store, state: state)
            let privacyService = PrivacyService(
                store: store,
                state: state,
                contextPersistence: contextPersistence
            )
            let updateService = UpdateService()
            let promptService = PromptService(state: state, libraryService: libraryService)
            let trackingService = TrackingService(
                store: store,
                state: state,
                sampler: SystemActivitySampler(idleThreshold: 30),
                permissionChecker: permissionChecker,
                promptService: promptService,
                eventObserver: WorkspaceActivityEventObserver()
            )
            let segmentEditingService = SegmentEditingService(store: store, state: state)
            let promptPanelCoordinator = PromptPanelCoordinator()

            self.state = state
            self.libraryService = libraryService
            self.projectSessionService = projectSessionService
            self.trackingService = trackingService
            self.dashboardService = dashboardService
            self.analyticsService = analyticsService
            self.privacyService = privacyService
            self.updateService = updateService
            self.promptService = promptService
            self.promptPanelCoordinator = promptPanelCoordinator
            self.menuBarViewModel = MenuBarViewModel(
                state: state,
                trackingService: trackingService,
                libraryService: libraryService,
                projectSessionService: projectSessionService,
                updateService: updateService
            )
            self.todayViewModel = TodayViewModel(
                state: state,
                libraryService: libraryService,
                segmentEditingService: segmentEditingService,
                dashboardService: dashboardService
            )
            self.settingsViewModel = SettingsViewModel(
                state: state,
                libraryService: libraryService,
                privacyService: privacyService,
                updateService: updateService
            )
            self.analyticsViewModel = AnalyticsViewModel(state: state, service: analyticsService)
            self.analyticsViewModel.coordinator = self

            self.menuBarViewModel.coordinator = self
            self.todayViewModel.coordinator = self
            promptPanelCoordinator.makeViewModel = { [weak self] prompt in
                guard let self else {
                    return nil
                }
                return SmartPromptViewModel(
                    prompt: prompt,
                    state: state,
                    promptService: promptService,
                    coordinator: self
                )
            }
            promptService.presenter = promptPanelCoordinator
            stateCancellable = state.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            #if DEBUG
            openMainWindowInDebugOnLaunch()
            #endif
            libraryService.refreshAccessibilityTrust(prompt: false)
            libraryService.loadState()
            projectSessionService.loadState()
            dashboardService.reload()
            if !UserDefaults.standard.bool(forKey: Self.hasSeenDefaultAutoSortPromptKey) {
                if todayViewModel.showDefaultAutoSortRulesIfNeeded() {
                    UserDefaults.standard.set(true, forKey: Self.hasSeenDefaultAutoSortPromptKey)
                }
            }
            if !state.isTracking {
                DispatchQueue.main.async { [weak self] in
                    self?.menuBarViewModel.toggleTracking()
                }
            }
        } catch {
            fatalError("Daily Replica could not open its local store: \(error)")
        }
    }

    var menuTitle: String {
        if state.latestSegment?.state == .inactive {
            return "Inactive"
        }
        return state.currentContext?.name ?? "Daily Replica"
    }

    var menuSystemImage: String {
        state.isTracking ? "record.circle.fill" : "pause.circle"
    }

    func bind(openWindow: OpenWindowAction) {
        self.openWindow = { id in
            openWindow(id: id)
        }
    }

    func openToday() {
        select(.today)
        libraryService.reloadToday()
        projectSessionService.reloadToday()
        dashboardService.reload()
        openMainWindow()
    }

    func openAnalytics() {
        select(.analytics)
        analyticsService.reload()
        openMainWindow()
    }

    func openSettings() {
        select(.categories)
        openMainWindow()
    }

    func openProjects() {
        select(.contexts)
        openMainWindow()
    }

    func openCategories() {
        select(.categories)
        openMainWindow()
    }

    private func openMainWindow() {
        openWindow?("main")
    }

    func select(_ section: AppSection) {
        selectedSection = section
        if let settingsSection = section.settingsSection {
            settingsViewModel.selectedSection = settingsSection
        }
    }

    func quit() {
        if state.isTracking {
            trackingService.stopTracking()
        }
        projectSessionService.closeActiveSession()
        NSApp.terminate(nil)
    }

    func showPrompt(_ prompt: SmartPrompt) {
        promptPanelCoordinator.showPrompt(prompt)
    }

    func dismissPrompt() {
        promptPanelCoordinator.dismissPrompt()
    }

    #if DEBUG
    private func openMainWindowInDebugOnLaunch() {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }
        openMainWindowInDebugOnLaunch(retryCount: 0)
    }

    private func openMainWindowInDebugOnLaunch(retryCount: Int) {
        guard retryCount < 20 else {
            return
        }

        if let openWindow {
            openWindow("main")
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.openMainWindowInDebugOnLaunch(retryCount: retryCount + 1)
        }
    }
    #endif

    private static func defaultStorePath() -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("DailyReplica", isDirectory: true)
            .appendingPathComponent("activity.sqlite")
            .path
    }
}

private struct CoordinatorWindowBindingModifier: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    let coordinator: AppCoordinator

    func body(content: Content) -> some View {
        content
            .onAppear {
                coordinator.bind(openWindow: openWindow)
            }
    }
}

extension View {
    func bindWindowActions(to coordinator: AppCoordinator) -> some View {
        modifier(CoordinatorWindowBindingModifier(coordinator: coordinator))
    }
}
