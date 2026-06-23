import Combine
import DailyReplicaCore
import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    weak var coordinator: AppCoordinating?

    private let state: AppState
    private let service: AnalyticsService
    private let calendar: Calendar
    private var stateCancellable: AnyCancellable?

    init(state: AppState, service: AnalyticsService, calendar: Calendar = .dailyReplica) {
        self.state = state
        self.service = service
        self.calendar = calendar
        stateCancellable = state.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var report: AnalyticsReport {
        state.analyticsReport
    }

    var selectedPeriod: AnalyticsPeriod {
        state.analyticsPeriod
    }

    var selectedDate: Date {
        state.analyticsDate
    }

    var selectedFilter: AnalyticsFilter {
        state.analyticsFilter
    }

    var selectedDrilldownDate: Date? {
        state.analyticsDrilldownDate
    }

    var categories: [CategoryDefinition] {
        state.categories
    }

    var contexts: [ProjectContext] {
        state.contexts
    }

    var selectedPeriodRange: DateInterval {
        selectedPeriod.interval(containing: selectedDate, calendar: calendar)
    }

    var dateRangeLabel: String {
        switch selectedPeriod {
        case .day:
            return selectedDate.formatted(date: .abbreviated, time: .omitted)
        case .week:
            return "\(selectedPeriodRange.start.formatted(date: .abbreviated, time: .omitted)) - \(selectedPeriodRange.end.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted))"
        case .month:
            return selectedPeriodRange.start.formatted(.dateTime.month(.wide).year())
        }
    }

    var appFilterOptions: [AnalyticsBreakdown] {
        report.appItems
    }

    var websiteFilterOptions: [AnalyticsBreakdown] {
        report.websiteItems
    }

    var isShowingDrilldown: Bool {
        selectedDrilldownDate != nil
    }

    var drilldownDateTitle: String {
        guard let selectedDrilldownDate else {
            return "Selected period"
        }
        return selectedDrilldownDate.formatted(date: .long, time: .omitted)
    }

    var canMoveBackward: Bool {
        canMove(by: -1)
    }

    var canMoveForward: Bool {
        canMove(by: 1)
    }

    func reload() {
        service.reload()
    }

    func setPeriod(_ period: AnalyticsPeriod) {
        service.setPeriod(period)
    }

    func movePeriod(by delta: Int) {
        service.movePeriod(by: delta)
    }

    func jumpToToday() {
        service.selectDate(Date())
    }

    func selectDrilldownDate(_ date: Date) {
        service.selectDate(date)
    }

    func clearDrilldown() {
        service.clearDrilldown()
    }

    func setCategoryFilter(_ categoryID: String?) {
        updateFilter { filter in
            filter.categoryID = categoryID
        }
    }

    func setContextFilter(_ contextID: UUID?) {
        updateFilter { filter in
            filter.contextID = contextID
        }
    }

    func setAppFilter(_ appIdentifier: String?) {
        updateFilter { filter in
            filter.appIdentifier = appIdentifier
        }
    }

    func setWebsiteFilter(_ websiteHost: String?) {
        updateFilter { filter in
            filter.websiteHost = websiteHost
        }
    }

    func clearFilter() {
        service.setFilter(.all)
    }

    func openToday() {
        coordinator?.openToday()
    }

    private func updateFilter(_ update: (inout AnalyticsFilter) -> Void) {
        var filter = selectedFilter
        update(&filter)
        service.setFilter(filter)
    }

    func selectedCategoryDisplayName(for categoryID: String) -> String {
        state.displayName(for: categoryID)
    }

    private func canMove(by delta: Int) -> Bool {
        guard let movedDate = calendar.date(
            byAdding: selectedPeriod.calendarComponent,
            value: delta,
            to: selectedDate
        ) else {
            return false
        }

        let targetInterval = selectedPeriod.interval(containing: movedDate, calendar: calendar)
        guard targetInterval.start <= Date() else {
            return false
        }

        guard let bounds = state.analyticsDateBounds else {
            return true
        }
        return bounds.intersects(targetInterval)
    }
}
