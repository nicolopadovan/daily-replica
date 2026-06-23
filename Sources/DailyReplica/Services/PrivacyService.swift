import DailyReplicaCore
import Foundation

@MainActor
final class PrivacyService {
    private let store: ActivityStore
    private let state: AppState
    private let contextPersistence: CurrentContextPersisting

    init(store: ActivityStore, state: AppState, contextPersistence: CurrentContextPersisting) {
        self.store = store
        self.state = state
        self.contextPersistence = contextPersistence
    }

    func exportJSONData() throws -> Data {
        try ActivityDataExporter.jsonData(snapshot: exportSnapshot())
    }

    func exportSegmentsCSVData() throws -> Data {
        let csv = ActivityDataExporter.segmentsCSV(segments: try allSegments())
        return Data(csv.utf8)
    }

    func clearActivityData() {
        do {
            try store.deleteAllActivityData()
            state.todaySegments = []
            state.todayProjectSessions = []
            state.dashboardSegments = []
            state.dashboardProjectSessions = []
            state.lastSampleDescription = "No local activity data"
        } catch {
            state.lastError = error.localizedDescription
        }
    }

    func resetAllData() {
        do {
            try store.deleteAllUserData()
            state.categories = try store.fetchCategories()
            state.contexts = []
            state.rules = []
            state.currentContextID = nil
            state.activePrompt = nil
            contextPersistence.saveCurrentContextID(nil)
            clearActivityData()
        } catch {
            state.lastError = error.localizedDescription
        }
    }

    private func exportSnapshot() throws -> ActivityExportSnapshot {
        ActivityExportSnapshot(
            categories: try store.fetchCategories(),
            contexts: try store.fetchContexts(includeArchived: true),
            rules: try store.fetchRules(),
            segments: try allSegments(),
            projectSessions: try allProjectSessions()
        )
    }

    private func allSegments() throws -> [ActivitySegment] {
        try store.fetchSegments(in: allTimeInterval)
    }

    private func allProjectSessions() throws -> [ProjectSession] {
        try store.fetchProjectSessions(in: allTimeInterval)
    }

    private var allTimeInterval: DateInterval {
        DateInterval(start: .distantPast, end: .distantFuture)
    }
}
