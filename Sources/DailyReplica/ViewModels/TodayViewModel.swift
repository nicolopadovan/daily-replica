import Combine
import DailyReplicaCore
import Foundation

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var selectedSegmentID: UUID?
    @Published var selectedSegmentIDs: Set<UUID> = []
    @Published var isCreatingCategory = false
    @Published var isCreatingProject = false
    @Published var newCategoryName = ""
    @Published var newProjectName = ""
    @Published var newProjectCategoryID = CategoryID.work.rawValue
    @Published var splitTime = Date()
    @Published var pendingAutoSortBatch: AutoSortRuleBatch?
    @Published var pendingAutoSortIsRetroactive = true

    weak var coordinator: AppCoordinating?

    private let state: AppState
    private let libraryService: LibraryService
    private let segmentEditingService: SegmentEditingService
    private let dashboardService: DashboardService
    private var rangeSelectionAnchorID: UUID?
    private var stateCancellable: AnyCancellable?

    init(
        state: AppState,
        libraryService: LibraryService,
        segmentEditingService: SegmentEditingService,
        dashboardService: DashboardService
    ) {
        self.state = state
        self.libraryService = libraryService
        self.segmentEditingService = segmentEditingService
        self.dashboardService = dashboardService
        stateCancellable = state.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var todaySegments: [ActivitySegment] { state.todaySegments }
    var todaySummary: ActivityDaySummary { state.todaySummary }
    var todayRibbonEntries: [ActivityRibbonEntry] { state.todayRibbonEntries }
    var dashboardPeriod: DashboardPeriod { state.dashboardPeriod }
    var dashboardSummary: ActivityDashboardSummary { state.dashboardSummary }
    var dashboardIntervalTitle: String {
        switch state.dashboardPeriod {
        case .day:
            return state.dashboardInterval.start.formatted(date: .abbreviated, time: .omitted)
        case .week:
            return "\(state.dashboardInterval.start.formatted(date: .abbreviated, time: .omitted)) - \(state.dashboardInterval.end.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted))"
        case .month:
            return state.dashboardInterval.start.formatted(.dateTime.month(.wide).year())
        }
    }
    var dashboardCategoryItems: [DashboardMetricItem] { Array(dashboardSummary.categoryItems.prefix(5)) }
    var dashboardProjectItems: [DashboardMetricItem] { Array(dashboardSummary.projectItems.prefix(5)) }
    var dashboardAppItems: [DashboardMetricItem] { Array(dashboardSummary.appItems.prefix(5)) }
    var dashboardWebsiteItems: [DashboardMetricItem] { Array(dashboardSummary.websiteItems.prefix(5)) }
    var dashboardDailyTotals: [DashboardDailyTotal] { dashboardSummary.dailyTotals }
    var currentContextName: String { state.currentContext?.name ?? "No current project" }
    var isTracking: Bool { state.isTracking }
    var categories: [CategoryDefinition] { state.categories }
    var contexts: [ProjectContext] { state.contexts }
    var activeProjectSession: ProjectSession? { state.activeProjectSession }
    var activeProjectElapsed: String {
        guard let activeProjectSession else {
            return "--"
        }
        return DurationFormatter.format(activeProjectSession.duration())
    }
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
        if selectedSegmentIDs.count == 1,
           let selectedSegmentID = selectedSegmentIDs.first,
           let segment = state.todaySegments.first(where: { $0.id == selectedSegmentID }) {
            return segment
        }
        if let selectedSegmentID,
           let segment = state.todaySegments.first(where: { $0.id == selectedSegmentID }) {
            return segment
        }
        return nil
    }

    var selectedSegments: [ActivitySegment] {
        let ids = selectedSegmentIDs.isEmpty ? Set(selectedSegmentID.map { [$0] } ?? []) : selectedSegmentIDs
        return state.todaySegments.filter { ids.contains($0.id) }
    }

    var selectedSegmentCount: Int {
        selectedSegments.count
    }

    func reloadToday() {
        libraryService.reloadToday()
        dashboardService.reload()
        clearSelectionIfMissing()
    }

    func setDashboardPeriod(_ period: DashboardPeriod) {
        dashboardService.setPeriod(period)
    }

    func clearSelectionIfMissing() {
        let validIDs = Set(state.todaySegments.map(\.id))
        selectedSegmentIDs.formIntersection(validIDs)
        if let selectedSegmentID, !validIDs.contains(selectedSegmentID) {
            self.selectedSegmentID = nil
        }
        if let rangeSelectionAnchorID, !validIDs.contains(rangeSelectionAnchorID) {
            self.rangeSelectionAnchorID = selectedSegmentIDs.first ?? selectedSegmentID
        }
        resetSplitTime(for: selectedSegment)
    }

    func selectSegment(id: UUID) {
        selectedSegmentIDs = [id]
        selectedSegmentID = id
        rangeSelectionAnchorID = id
        resetSplitTime(for: selectedSegment)
    }

    func toggleSegmentSelection(id: UUID) {
        if selectedSegmentIDs.contains(id) {
            selectedSegmentIDs.remove(id)
        } else {
            selectedSegmentIDs.insert(id)
        }
        selectedSegmentID = selectedSegmentIDs.isEmpty ? nil : (selectedSegmentIDs.count == 1 ? selectedSegmentIDs.first : id)
        rangeSelectionAnchorID = id
        resetSplitTime(for: selectedSegment)
    }

    func selectSegmentRange(to id: UUID) {
        guard let anchorID = rangeSelectionAnchorID ?? selectedSegmentID ?? selectedSegmentIDs.first,
              let anchorIndex = state.todaySegments.firstIndex(where: { $0.id == anchorID }),
              let endIndex = state.todaySegments.firstIndex(where: { $0.id == id }) else {
            selectSegment(id: id)
            return
        }
        let range = anchorIndex <= endIndex ? anchorIndex...endIndex : endIndex...anchorIndex
        selectedSegmentIDs = Set(state.todaySegments[range].map(\.id))
        selectedSegmentID = id
        resetSplitTime(for: selectedSegment)
    }

    func selectSegments(ids: Set<UUID>) {
        let validIDs = Set(state.todaySegments.map(\.id))
        selectedSegmentIDs = ids.intersection(validIDs)
        selectedSegmentID = selectedSegmentIDs.first
        rangeSelectionAnchorID = selectedSegmentID
        resetSplitTime(for: selectedSegment)
    }

    func clearSegmentSelection() {
        selectedSegmentIDs = []
        selectedSegmentID = nil
        rangeSelectionAnchorID = nil
        resetSplitTime(for: nil)
    }

    func displayName(for categoryID: String) -> String {
        state.displayName(for: categoryID)
    }

    func editSegmentCategory(segmentID: UUID, categoryID: String) {
        let original = state.todaySegments.first { $0.id == segmentID }
        segmentEditingService.editCategory(segmentID: segmentID, categoryID: categoryID)
        dashboardService.reload()
        queueAutoSortPromptIfNeeded(for: original, categoryID: categoryID)
    }

    func editSegmentContext(segmentID: UUID, contextID: UUID?) {
        segmentEditingService.editContext(segmentID: segmentID, contextID: contextID)
        dashboardService.reload()
    }

    func editSelectedSegmentsCategory(categoryID: String) {
        let originals = selectedSegments
        selectedSegments.forEach { segmentEditingService.editCategory(segmentID: $0.id, categoryID: categoryID) }
        dashboardService.reload()
        queueAutoSortPromptIfNeeded(for: originals, categoryID: categoryID)
    }

    func confirmPendingAutoSortRule() {
        guard let pendingAutoSortBatch else {
            return
        }
        for request in pendingAutoSortBatch.requests {
            libraryService.addRule(
                kind: request.kind,
                pattern: request.pattern,
                categoryID: request.categoryID,
                retroactive: pendingAutoSortIsRetroactive
            )
        }
        self.pendingAutoSortBatch = nil
        pendingAutoSortIsRetroactive = true
        dashboardService.reload()
    }

    func cancelPendingAutoSortRule() {
        pendingAutoSortBatch = nil
        pendingAutoSortIsRetroactive = true
    }

    func editSelectedSegmentsContext(contextID: UUID?) {
        selectedSegments.forEach { segmentEditingService.editContext(segmentID: $0.id, contextID: contextID) }
        dashboardService.reload()
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
        selectedSegmentIDs = [right.id]
        rangeSelectionAnchorID = right.id
        resetSplitTime(for: right)
        dashboardService.reload()
    }

    func mergeSelectedSegmentWithPrevious() {
        guard let segmentID = selectedSegment?.id,
              let previous = segmentEditingService.segment(before: segmentID),
              let merged = segmentEditingService.mergeSegment(segmentID: segmentID, withAdjacentSegmentID: previous.id) else {
            return
        }
        selectedSegmentID = merged.id
        selectedSegmentIDs = [merged.id]
        rangeSelectionAnchorID = merged.id
        resetSplitTime(for: merged)
        dashboardService.reload()
    }

    func mergeSelectedSegmentWithNext() {
        guard let segmentID = selectedSegment?.id,
              let next = segmentEditingService.segment(after: segmentID),
              let merged = segmentEditingService.mergeSegment(segmentID: segmentID, withAdjacentSegmentID: next.id) else {
            return
        }
        selectedSegmentID = merged.id
        selectedSegmentIDs = [merged.id]
        rangeSelectionAnchorID = merged.id
        resetSplitTime(for: merged)
        dashboardService.reload()
    }

    func deleteSelectedSegment() {
        guard let segmentID = selectedSegment?.id else {
            return
        }
        segmentEditingService.markInactive(segmentID: segmentID)
        resetSplitTime(for: selectedSegment)
        dashboardService.reload()
    }

    @discardableResult
    func createCategory(name: String) -> CategoryDefinition? {
        libraryService.addCategory(name: name)
    }

    @discardableResult
    func createContext(name: String, defaultCategoryID: String?) -> ProjectContext? {
        libraryService.addContext(name: name, defaultCategoryID: defaultCategoryID, selectCurrent: false)
    }

    func openSettings() {
        coordinator?.openSettings()
    }

    func openProjects() {
        coordinator?.openProjects()
    }

    func openCategories() {
        coordinator?.openCategories()
    }

    func openAnalytics() {
        coordinator?.openAnalytics()
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

    private func queueAutoSortPromptIfNeeded(for segment: ActivitySegment?, categoryID: String) {
        guard let segment else {
            return
        }
        queueAutoSortPromptIfNeeded(for: [segment], categoryID: categoryID)
    }

    private func queueAutoSortPromptIfNeeded(for segments: [ActivitySegment], categoryID: String) {
        guard categoryID != CategoryID.unclassified.rawValue,
              categoryID != CategoryID.inactive.rawValue else {
            return
        }
        let requests = segments.compactMap { segment -> AutoSortRuleRequest? in
            guard
              segment.state == .active,
              segment.categoryID == CategoryID.unclassified.rawValue,
              let target = autoSortTarget(for: segment),
              libraryService.existingRule(kind: target.kind, pattern: target.pattern) == nil else {
                return nil
            }
            return AutoSortRuleRequest(
                kind: target.kind,
                pattern: target.pattern,
                categoryID: categoryID,
                title: target.title
            )
        }
        let uniqueRequests = requests.reduce(into: [String: AutoSortRuleRequest]()) { partialResult, request in
            partialResult["\(request.kind.rawValue):\(request.pattern)"] = request
        }
        let sortedRequests = uniqueRequests.values.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        guard !sortedRequests.isEmpty else {
            return
        }
        pendingAutoSortBatch = AutoSortRuleBatch(requests: sortedRequests)
        pendingAutoSortIsRetroactive = true
    }

    private func autoSortTarget(for segment: ActivitySegment) -> (kind: ClassificationRuleKind, pattern: String, title: String)? {
        if let bundleID = segment.appBundleID, !bundleID.isEmpty {
            return (.appBundleID, bundleID, segment.appName ?? bundleID)
        }
        if let appName = segment.appName, !appName.isEmpty {
            return (.appName, appName, appName)
        }
        return nil
    }
}
