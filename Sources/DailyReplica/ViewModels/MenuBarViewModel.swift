import Combine
import DailyReplicaCore
import Foundation

@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published var isCreatingProject = false
    @Published var newProjectName = ""
    @Published var newProjectCategoryID = CategoryID.work.rawValue

    weak var coordinator: AppCoordinating?

    private let state: AppState
    private let trackingService: TrackingService
    private let libraryService: LibraryService
    private var stateCancellable: AnyCancellable?

    init(state: AppState, trackingService: TrackingService, libraryService: LibraryService) {
        self.state = state
        self.trackingService = trackingService
        self.libraryService = libraryService
        stateCancellable = state.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var isTracking: Bool { state.isTracking }
    var categories: [CategoryDefinition] { state.categories }
    var contexts: [ProjectContext] { state.contexts }
    var currentContextID: UUID? { state.currentContextID }
    var latestSegment: ActivitySegment? { state.latestSegment }
    var lastError: String? { state.lastError }
    var lastSampleDescription: String { state.lastSampleDescription }
    var accessibilityTrusted: Bool { state.accessibilityTrusted }
    var todaySummary: ActivityDaySummary { state.todaySummary }
    var todayRibbonEntries: [ActivityRibbonEntry] { state.todayRibbonEntries }

    var latestSegmentElapsed: TimeInterval {
        guard let latestSegment else {
            return 0
        }
        return max(0, Date().timeIntervalSince(latestSegment.start))
    }

    var currentTitle: String {
        if latestSegment?.state == .inactive {
            return "Inactive"
        }
        return latestSegment?.appName ?? lastSampleDescription
    }

    var currentCategoryID: String {
        latestSegment?.categoryID ?? CategoryID.unclassified.rawValue
    }

    var currentElapsed: String {
        latestSegment == nil ? "--" : DurationFormatter.format(latestSegmentElapsed)
    }

    func displayName(for categoryID: String) -> String {
        state.displayName(for: categoryID)
    }

    func toggleTracking() {
        isTracking ? trackingService.stopTracking() : trackingService.startTracking()
    }

    func setCurrentContext(selection: String) {
        let previousContextID = state.currentContextID
        libraryService.setCurrentContext(id: UUID(uuidString: selection))
        if state.isTracking, previousContextID != state.currentContextID {
            trackingService.handleEvent(.heartbeat)
        }
    }

    func showCreateProject() {
        isCreatingProject = true
    }

    func cancelCreateProject() {
        isCreatingProject = false
        newProjectName = ""
    }

    func createProject() {
        guard libraryService.addContext(name: newProjectName, defaultCategoryID: newProjectCategoryID) != nil else {
            return
        }
        newProjectName = ""
        isCreatingProject = false
    }

    func requestAccessibilityPermission() {
        libraryService.refreshAccessibilityTrust(prompt: true)
    }

    func openToday() {
        coordinator?.openToday()
    }

    func openSettings() {
        coordinator?.openSettings()
    }

    func quit() {
        coordinator?.quit()
    }
}
