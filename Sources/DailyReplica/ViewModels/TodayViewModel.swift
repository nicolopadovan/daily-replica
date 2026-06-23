import Combine
import DailyReplicaCore
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var selectedSegmentID: UUID?
    @Published var isCreatingCategory = false
    @Published var isCreatingProject = false
    @Published var newCategoryName = ""
    @Published var newProjectName = ""
    @Published var newProjectCategoryID = CategoryID.work.rawValue
    @Published var splitTime = Date()

    weak var coordinator: AppCoordinating?

    private let state: AppState
    private let libraryService: LibraryService
    private let segmentEditingService: SegmentEditingService
    private var stateCancellable: AnyCancellable?

    init(
        state: AppState,
        libraryService: LibraryService,
        segmentEditingService: SegmentEditingService
    ) {
        self.state = state
        self.libraryService = libraryService
        self.segmentEditingService = segmentEditingService
        stateCancellable = state.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var todaySegments: [ActivitySegment] { state.todaySegments }
    var todaySummary: ActivityDaySummary { state.todaySummary }
    var todayRibbonEntries: [ActivityRibbonEntry] { state.todayRibbonEntries }
    var currentContextName: String { state.currentContext?.name ?? "No current project" }
    var isTracking: Bool { state.isTracking }
    var categories: [CategoryDefinition] { state.categories }
    var contexts: [ProjectContext] { state.contexts }
    var canSplitSelectedSegment: Bool {
        guard let segment = selectedSegment else {
            return false
        }
        return splitTime > segment.start && splitTime < segment.end
    }

    var canMergeSelectedSegmentWithPrevious: Bool {
        guard let segmentID = selectedSegment?.id else {
            return false
        }
        return segmentEditingService.segment(before: segmentID) != nil
    }

    var canMergeSelectedSegmentWithNext: Bool {
        guard let segmentID = selectedSegment?.id else {
            return false
        }
        return segmentEditingService.segment(after: segmentID) != nil
    }

    var selectedSegment: ActivitySegment? {
        if let selectedSegmentID,
           let segment = state.todaySegments.first(where: { $0.id == selectedSegmentID }) {
            return segment
        }
        return state.todaySegments.last
    }

    func reloadToday() {
        libraryService.reloadToday()
        selectLatestIfNeeded()
    }

    func selectLatestIfNeeded() {
        if selectedSegmentID == nil || !state.todaySegments.contains(where: { $0.id == selectedSegmentID }) {
            selectedSegmentID = state.todaySegments.last?.id
        }
        resetSplitTime(for: selectedSegment)
    }

    func selectSegment(id: UUID) {
        selectedSegmentID = id
        resetSplitTime(for: selectedSegment)
    }

    func displayName(for categoryID: String) -> String {
        state.displayName(for: categoryID)
    }

    func editSegmentCategory(segmentID: UUID, categoryID: String) {
        segmentEditingService.editCategory(segmentID: segmentID, categoryID: categoryID)
    }

    func editSegmentContext(segmentID: UUID, contextID: UUID?) {
        segmentEditingService.editContext(segmentID: segmentID, contextID: contextID)
    }

    func resetSplitTime(for segment: ActivitySegment?) {
        guard let segment else {
            splitTime = Date()
            return
        }
        splitTime = segment.start.addingTimeInterval(segment.duration / 2)
    }

    func splitSelectedSegment() {
        guard let segmentID = selectedSegment?.id,
              let right = segmentEditingService.splitSegment(segmentID: segmentID, at: splitTime) else {
            return
        }
        selectedSegmentID = right.id
        resetSplitTime(for: right)
    }

    func mergeSelectedSegmentWithPrevious() {
        guard let segmentID = selectedSegment?.id,
              let previous = segmentEditingService.segment(before: segmentID),
              let merged = segmentEditingService.mergeSegment(segmentID: segmentID, withAdjacentSegmentID: previous.id) else {
            return
        }
        selectedSegmentID = merged.id
        resetSplitTime(for: merged)
    }

    func mergeSelectedSegmentWithNext() {
        guard let segmentID = selectedSegment?.id,
              let next = segmentEditingService.segment(after: segmentID),
              let merged = segmentEditingService.mergeSegment(segmentID: segmentID, withAdjacentSegmentID: next.id) else {
            return
        }
        selectedSegmentID = merged.id
        resetSplitTime(for: merged)
    }

    @discardableResult
    func createCategory(name: String) -> CategoryDefinition? {
        libraryService.addCategory(name: name)
    }

    @discardableResult
    func createContext(name: String, defaultCategoryID: String?) -> ProjectContext? {
        libraryService.addContext(name: name, defaultCategoryID: defaultCategoryID)
    }

    func openSettings() {
        coordinator?.openSettings()
    }

    func toggleCategoryCreation() {
        isCreatingCategory.toggle()
    }

    func toggleProjectCreation() {
        isCreatingProject.toggle()
    }

    func cancelCategoryCreation() {
        isCreatingCategory = false
        newCategoryName = ""
    }

    func cancelProjectCreation() {
        isCreatingProject = false
        newProjectName = ""
    }

    func createCategoryAndUse(segmentID: UUID) {
        guard let category = createCategory(name: newCategoryName) else {
            return
        }
        editSegmentCategory(segmentID: segmentID, categoryID: category.id)
        cancelCategoryCreation()
    }

    func createProjectAndUse(segmentID: UUID) {
        guard let context = createContext(name: newProjectName, defaultCategoryID: newProjectCategoryID) else {
            return
        }
        editSegmentContext(segmentID: segmentID, contextID: context.id)
        cancelProjectCreation()
    }
}
