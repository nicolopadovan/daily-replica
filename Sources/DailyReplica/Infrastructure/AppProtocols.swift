import DailyReplicaCore
import Foundation

protocol ActivityStore: AnyObject {
    func fetchCategories() throws -> [CategoryDefinition]
    func upsertCategory(_ category: CategoryDefinition) throws
    func fetchContexts(includeArchived: Bool) throws -> [ProjectContext]
    func upsertContext(_ context: ProjectContext) throws
    func fetchRules() throws -> [ClassificationRule]
    func upsertRule(_ rule: ClassificationRule) throws
    func deleteRule(id: UUID) throws
    func upsertSegment(_ segment: ActivitySegment) throws
    func deleteSegment(id: UUID) throws
    func fetchSegments(in interval: DateInterval) throws -> [ActivitySegment]
    func fetchProjectSessions(in interval: DateInterval) throws -> [ProjectSession]
    func fetchOpenProjectSession() throws -> ProjectSession?
    func upsertProjectSession(_ session: ProjectSession) throws
}

extension ActivityStore {
    func fetchContexts() throws -> [ProjectContext] {
        try fetchContexts(includeArchived: false)
    }
}

extension SQLiteActivityStore: ActivityStore {}

protocol ActivitySampling {
    func sample(now: Date, accessibilityTrusted: Bool) -> FocusSample
}

enum TrackingEvent: Equatable {
    case heartbeat
    case appActivated
    case appTerminated
    case willSleep
    case didWake
    case screensDidSleep
    case screensDidWake
    case sessionDidResignActive
    case sessionDidBecomeActive
}

@MainActor
protocol ActivityEventObserving: AnyObject {
    var onEvent: ((TrackingEvent) -> Void)? { get set }
    func start()
    func stop()
}

protocol PermissionChecking {
    func isAccessibilityTrusted(prompt: Bool) -> Bool
}

protocol CurrentContextPersisting {
    func loadCurrentContextID() -> UUID?
    func saveCurrentContextID(_ id: UUID?)
}

@MainActor
protocol PromptPresenting: AnyObject {
    func showPrompt(_ prompt: SmartPrompt)
    func dismissPrompt()
}

@MainActor
protocol AppCoordinating: AnyObject {
    func openToday()
    func openSettings()
    func quit()
    func showPrompt(_ prompt: SmartPrompt)
    func dismissPrompt()
}

struct UserDefaultsCurrentContextStore: CurrentContextPersisting {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "currentContextID") {
        self.defaults = defaults
        self.key = key
    }

    func loadCurrentContextID() -> UUID? {
        defaults.string(forKey: key).flatMap(UUID.init(uuidString:))
    }

    func saveCurrentContextID(_ id: UUID?) {
        if let id {
            defaults.set(id.uuidString, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
