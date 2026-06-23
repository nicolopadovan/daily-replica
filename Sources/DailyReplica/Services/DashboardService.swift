import DailyReplicaCore
import Foundation

@MainActor
final class DashboardService {
    private let store: ActivityStore
    private let state: AppState
    private let calendar: Calendar

    init(store: ActivityStore, state: AppState, calendar: Calendar = .dailyReplica) {
        self.store = store
        self.state = state
        self.calendar = calendar
    }

    func setPeriod(_ period: DashboardPeriod, now: Date = Date()) {
        state.dashboardPeriod = period
        reload(now: now)
    }

    func reload(now: Date = Date()) {
        let interval = state.dashboardPeriod.interval(containing: now, calendar: calendar)
        do {
            state.dashboardInterval = interval
            state.dashboardSegments = try store.fetchSegments(in: interval)
            state.dashboardProjectSessions = try store.fetchProjectSessions(in: interval)
        } catch {
            state.lastError = error.localizedDescription
        }
    }
}
