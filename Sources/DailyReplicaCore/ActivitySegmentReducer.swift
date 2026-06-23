import Foundation

public struct ActivitySegmentReducer: Sendable {
    public init() {}

    public func ingest(_ sample: ClassifiedSample, into segments: inout [ActivitySegment]) {
        let now = sample.focus.timestamp

        if segments.isEmpty {
            segments.append(Self.makeSegment(from: sample, start: now, end: now))
            return
        }

        guard var last = segments.popLast() else {
            return
        }

        if last.matchesContinuation(sample) {
            last.end = max(last.end, now)
            last.updatedAt = now
            segments.append(last)
            return
        }

        if now > last.end {
            last.end = now
            last.updatedAt = now
        }
        segments.append(last)
        segments.append(Self.makeSegment(from: sample, start: now, end: now))
    }

    public func editSegment(
        id: UUID,
        in segments: inout [ActivitySegment],
        categoryID: String? = nil,
        context: ProjectContext? = nil,
        note: String? = nil,
        editedAt: Date = Date()
    ) {
        guard let index = segments.firstIndex(where: { $0.id == id }) else {
            return
        }
        segments[index] = segments[index].applyingManualEdit(
            categoryID: categoryID,
            context: context,
            note: note,
            editedAt: editedAt
        )
    }

    public func splitSegment(
        id: UUID,
        at splitTime: Date,
        in segments: inout [ActivitySegment],
        editedAt: Date = Date()
    ) -> (left: ActivitySegment, right: ActivitySegment)? {
        guard let index = segments.firstIndex(where: { $0.id == id }) else {
            return nil
        }

        let segment = segments[index]
        guard splitTime > segment.start, splitTime < segment.end else {
            return nil
        }

        var left = segment
        left.end = splitTime
        left.updatedAt = editedAt

        var right = segment
        right.id = UUID()
        right.start = splitTime
        right.createdAt = editedAt
        right.updatedAt = editedAt

        segments.replaceSubrange(index...index, with: [left, right])
        return (left, right)
    }

    public func mergeSegment(
        id: UUID,
        withAdjacentID adjacentID: UUID,
        in segments: inout [ActivitySegment],
        editedAt: Date = Date()
    ) -> ActivitySegment? {
        guard let selectedIndex = segments.firstIndex(where: { $0.id == id }),
              let adjacentIndex = segments.firstIndex(where: { $0.id == adjacentID }),
              abs(selectedIndex - adjacentIndex) == 1 else {
            return nil
        }

        let selected = segments[selectedIndex]
        let adjacent = segments[adjacentIndex]
        var merged = selected
        merged.start = min(selected.start, adjacent.start)
        merged.end = max(selected.end, adjacent.end)
        merged.updatedAt = editedAt

        segments.remove(at: adjacentIndex)
        if let updatedIndex = segments.firstIndex(where: { $0.id == id }) {
            segments[updatedIndex] = merged
        }
        return merged
    }

    public static func makeSegment(from sample: ClassifiedSample, start: Date, end: Date) -> ActivitySegment {
        ActivitySegment(
            start: start,
            end: end,
            state: sample.focus.state,
            appBundleID: sample.focus.appBundleID,
            appName: sample.focus.appName,
            windowTitle: sample.focus.windowTitle,
            urlString: sample.focus.urlString,
            urlHost: sample.focus.urlHost,
            categoryID: sample.categoryID,
            contextID: sample.contextID,
            contextName: sample.contextName,
            createdAt: start,
            updatedAt: end
        )
    }
}
