import DailyReplicaCore
import Foundation

@MainActor
final class ProjectSessionService {
    private let store: ActivityStore
    private let state: AppState
    private let contextPersistence: CurrentContextPersisting

    init(
        store: ActivityStore,
        state: AppState,
        contextPersistence: CurrentContextPersisting
    ) {
        self.store = store
        self.state = state
        self.contextPersistence = contextPersistence
    }

    func loadState(now: Date = Date()) {
        reloadToday(now: now)
        if let openSession = try? store.fetchOpenProjectSession(),
           state.contexts.contains(where: { $0.id == openSession.contextID }) {
            state.currentContextID = openSession.contextID
            contextPersistence.saveCurrentContextID(openSession.contextID)
            return
        }
        if let persistedID = contextPersistence.loadCurrentContextID(),
           state.contexts.contains(where: { $0.id == persistedID }) {
            state.currentContextID = persistedID
        } else {
            state.currentContextID = state.contexts.first?.id
        }
    }

    func setCurrentContext(id: UUID?, now: Date = Date()) {
        let contextChanged = id != state.currentContextID
        guard contextChanged || state.activeProjectSession == nil else {
            return
        }

        if contextChanged {
            closeActiveSession(now: now)
            state.currentContextID = id
            contextPersistence.saveCurrentContextID(id)
        }

        guard let id,
              let context = state.contexts.first(where: { $0.id == id }) else {
            return
        }

        let session = ProjectSession(
            contextID: id,
            contextName: context.name,
            start: now,
            createdAt: now,
            updatedAt: now
        )
        state.todayProjectSessions.append(session)
        persist(session)
    }

    func closeActiveSession(now: Date = Date()) {
        guard let index = state.todayProjectSessions.lastIndex(where: { $0.end == nil }) else {
            return
        }
        var session = state.todayProjectSessions[index]
        session.end = max(now, session.start)
        session.updatedAt = now
        state.todayProjectSessions[index] = session
        persist(session)
    }

    func reloadToday(now: Date = Date()) {
        do {
            state.todayProjectSessions = try store.fetchProjectSessions(in: DateInterval.day(containing: now))
        } catch {
            state.lastError = error.localizedDescription
        }
    }

    private func persist(_ session: ProjectSession) {
        do {
            try store.upsertProjectSession(session)
        } catch {
            state.lastError = error.localizedDescription
        }
    }
}
