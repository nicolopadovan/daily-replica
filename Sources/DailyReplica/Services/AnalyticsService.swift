import DailyReplicaCore
import Foundation

@MainActor
final class AnalyticsService {
    private let store: ActivityStore
    private let state: AppState
    private let calendar: Calendar

    init(store: ActivityStore, state: AppState, calendar: Calendar = .dailyReplica) {
        self.store = store
        self.state = state
        self.calendar = calendar
    }

    func setPeriod(_ period: AnalyticsPeriod, now: Date = Date()) {
        state.analyticsPeriod = period
        state.analyticsDrilldownDate = nil
        reload(now: now)
    }

    func movePeriod(by delta: Int, now: Date = Date()) {
        guard let movedDate = calendar.date(
            byAdding: state.analyticsPeriod.calendarComponent,
            value: delta,
            to: state.analyticsDate
        ) else {
            return
        }
        state.analyticsDate = clampDate(movedDate)
        state.analyticsDrilldownDate = nil
        reload(now: now)
    }

    func selectDate(_ date: Date, now: Date = Date()) {
        let clampedDate = clampDate(date)
        state.analyticsDate = clampedDate
        state.analyticsDrilldownDate = DateInterval.day(containing: clampedDate, calendar: calendar).start
        reload(now: now)
    }

    func setFilter(_ filter: AnalyticsFilter?) {
        state.analyticsFilter = filter ?? .all
        reload()
    }

    func clearDrilldown() {
        state.analyticsDrilldownDate = nil
        reload()
    }

    func reload(now: Date = Date()) {
        updateBounds(now: now)
        state.analyticsDate = clampDate(state.analyticsDate)

        if let bounds = state.analyticsDateBounds {
            if bounds.start == bounds.end || bounds.start >= bounds.end {
                state.analyticsDateBounds = nil
                state.analyticsDrilldownDate = nil
                state.analyticsReport = AnalyticsReport.empty
                return
            }

            if let selectedDate = state.analyticsDrilldownDate, !bounds.contains(selectedDate) {
                state.analyticsDrilldownDate = nil
            }
        } else {
            state.analyticsDrilldownDate = nil
        }

        let interval = state.analyticsPeriod.interval(containing: state.analyticsDate, calendar: calendar)

        do {
            let segments = try store.fetchSegments(in: interval)
            let sessions = try store.fetchProjectSessions(in: interval)
            state.analyticsReport = AnalyticsPresenter.report(
                for: segments,
                sessions: sessions,
                in: interval,
                filter: state.analyticsFilter,
                drilldownDate: state.analyticsDrilldownDate,
                period: state.analyticsPeriod,
                calendar: calendar
            )
        } catch {
            state.lastError = error.localizedDescription
        }
    }

    private func updateBounds(now: Date = Date()) {
        do {
            guard let bounds = try store.fetchSegmentDateBounds(),
                  bounds.start < bounds.end else {
                state.analyticsDateBounds = nil
                state.analyticsReport = AnalyticsReport.empty
                return
            }
            state.analyticsDateBounds = bounds
            if bounds.start > now {
                state.analyticsDate = bounds.start
            } else if bounds.end <= now {
                state.analyticsDate = min(state.analyticsDate, bounds.end)
            }
        } catch {
            state.lastError = error.localizedDescription
        }
    }

    private func clampDate(_ date: Date) -> Date {
        guard let bounds = state.analyticsDateBounds else {
            return date
        }
        guard bounds.start < bounds.end else {
            return bounds.start
        }
        let maxAllowed = bounds.end.addingTimeInterval(-1)
        return min(max(date, bounds.start), maxAllowed)
    }
}
