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

    private func persistSegment(id: UUID) {
        guard let segment = state.todaySegments.first(where: { $0.id == id }) else {
            return
        }
        do {
            try store.upsertSegment(segment)
        } catch {
            state.lastError = error.localizedDescription
        }
    }
}
