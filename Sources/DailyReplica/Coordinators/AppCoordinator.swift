import AppKit
import Combine
import DailyReplicaCore
import Foundation
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject, AppCoordinating {
    let state: AppState
    let menuBarViewModel: MenuBarViewModel
    let todayViewModel: TodayViewModel
    let settingsViewModel: SettingsViewModel

    private let libraryService: LibraryService
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
            self.promptService = promptService
            self.promptPanelCoordinator = promptPanelCoordinator
            self.menuBarViewModel = MenuBarViewModel(
                state: state,
                trackingService: trackingService,
                libraryService: libraryService
            )
            self.todayViewModel = TodayViewModel(
                state: state,
                libraryService: libraryService,
                segmentEditingService: segmentEditingService
            )
            self.settingsViewModel = SettingsViewModel(
                state: state,
                libraryService: libraryService
            )

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
            libraryService.loadState()
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
        libraryService.reloadToday()
        openWindow?("today")
    }

    func openSettings() {
        openWindow?("settings")
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func showPrompt(_ prompt: SmartPrompt) {
        promptPanelCoordinator.showPrompt(prompt)
    }

    func dismissPrompt() {
        promptPanelCoordinator.dismissPrompt()
    }

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
