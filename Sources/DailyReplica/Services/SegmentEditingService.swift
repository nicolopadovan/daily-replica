import DailyReplicaCore
import Foundation

@MainActor
final class SegmentEditingService {
    private let store: ActivityStore
    private let state: AppState
    private let reducer: ActivitySegmentReducer

    init(store: ActivityStore, state: AppState, reducer: ActivitySegmentReducer = ActivitySegmentReducer()) {
        self.store = store
        self.state = state
        self.reducer = reducer
    }

    func editCategory(segmentID: UUID, categoryID: String) {
        reducer.editSegment(id: segmentID, in: &state.todaySegments, categoryID: categoryID)
        persistSegment(id: segmentID)
    }

    func editContext(segmentID: UUID, contextID: UUID?) {
        guard let index = state.todaySegments.firstIndex(where: { $0.id == segmentID }) else {
            return
        }
        var segment = state.todaySegments[index]
        if let contextID, let context = state.contexts.first(where: { $0.id == contextID }) {
            segment = segment.applyingManualEdit(context: context)
        } else {
            segment.contextID = nil
            segment.contextName = nil
            segment.manualContextID = nil
            segment.updatedAt = Date()
        }
        state.todaySegments[index] = segment
        persistSegment(id: segmentID)
    }

    func markInactive(segmentID: UUID) {
        guard let index = state.todaySegments.firstIndex(where: { $0.id == segmentID }) else {
            return
        }
        var segment = state.todaySegments[index]
        segment.state = .inactive
        segment.appBundleID = nil
        segment.appName = nil
        segment.windowTitle = nil
        segment.urlString = nil
        segment.urlHost = nil
        segment.categoryID = CategoryID.inactive.rawValue
        segment.contextID = nil
        segment.contextName = nil
        segment.manualCategoryID = nil
        segment.manualContextID = nil
        segment.manualNote = nil
        segment.updatedAt = Date()
        state.todaySegments[index] = segment
        persist(segment)
    }

    func splitSegment(segmentID: UUID, at splitTime: Date) -> ActivitySegment? {
        guard let split = reducer.splitSegment(id: segmentID, at: splitTime, in: &state.todaySegments) else {
            return nil
        }
        persist(split.left)
        persist(split.right)
        return split.right
    }

    func mergeSegment(segmentID: UUID, withAdjacentSegmentID adjacentID: UUID) -> ActivitySegment? {
        guard let merged = reducer.mergeSegment(id: segmentID, withAdjacentID: adjacentID, in: &state.todaySegments) else {
            return nil
        }
        persist(merged)
        do {
            try store.deleteSegment(id: adjacentID)
        } catch {
            state.lastError = error.localizedDescription
        }
        return merged
    }

    func segment(before segmentID: UUID) -> ActivitySegment? {
        guard let index = state.todaySegments.firstIndex(where: { $0.id == segmentID }),
              index > state.todaySegments.startIndex else {
            return nil
        }
        return state.todaySegments[state.todaySegments.index(before: index)]
    }

    func segment(after segmentID: UUID) -> ActivitySegment? {
        guard let index = state.todaySegments.firstIndex(where: { $0.id == segmentID }) else {
            return nil
        }
        let nextIndex = state.todaySegments.index(after: index)
        guard nextIndex < state.todaySegments.endIndex else {
            return nil
        }
        return state.todaySegments[nextIndex]
    }

    private func persistSegment(id: UUID) {
        guard let segment = state.todaySegments.first(where: { $0.id == id }) else {
            return
        }
        persist(segment)
    }

    private func persist(_ segment: ActivitySegment) {
        do {
            try store.upsertSegment(segment)
        } catch {
            state.lastError = error.localizedDescription
        }
    }
}
