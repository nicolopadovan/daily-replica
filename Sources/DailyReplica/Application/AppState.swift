import DailyReplicaCore
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var isTracking = false
    @Published var categories: [CategoryDefinition] = CategoryID.builtInDefinitions
    @Published var contexts: [ProjectContext] = []
    @Published var currentContextID: UUID?
    @Published var todayProjectSessions: [ProjectSession] = []
    @Published var rules: [ClassificationRule] = []
    @Published var todaySegments: [ActivitySegment] = []
    @Published var activePrompt: SmartPrompt?
    @Published var lastError: String?
    @Published var lastSampleDescription = "Not tracking"
    @Published var accessibilityTrusted = false

    var currentContext: ProjectContext? {
        guard let currentContextID else {
            return nil
        }
        return contexts.first { $0.id == currentContextID }
    }

    var activeProjectSession: ProjectSession? {
        todayProjectSessions.last { $0.end == nil }
    }

    var todayInterval: DateInterval {
        DateInterval.day(containing: Date())
    }

    var todaySummary: ActivityDaySummary {
        ActivityDayPresenter.summary(for: todaySegments, in: todayInterval)
    }

    var todayRibbonEntries: [ActivityRibbonEntry] {
        ActivityDayPresenter.ribbonEntries(for: todaySegments, in: todayInterval)
    }

    var latestSegment: ActivitySegment? {
        todaySegments.last
    }

    func displayName(for categoryID: String) -> String {
        categories.first { $0.id == categoryID }?.name ?? categoryID
    }
}
