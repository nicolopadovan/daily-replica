import Foundation

public struct ActivityCategoryDuration: Equatable, Identifiable, Sendable {
    public var id: String { categoryID }
    public var categoryID: String
    public var duration: TimeInterval

    public init(categoryID: String, duration: TimeInterval) {
        self.categoryID = categoryID
        self.duration = duration
    }
}

public struct ActivityDaySummary: Equatable, Sendable {
    public var totalDuration: TimeInterval
    public var activeDuration: TimeInterval
    public var inactiveDuration: TimeInterval
    public var unclassifiedDuration: TimeInterval
    public var editedCount: Int
    public var segmentCount: Int
    public var categoryDurations: [String: TimeInterval]

    public init(
        totalDuration: TimeInterval,
        activeDuration: TimeInterval,
        inactiveDuration: TimeInterval,
        unclassifiedDuration: TimeInterval,
        editedCount: Int,
        segmentCount: Int,
        categoryDurations: [String: TimeInterval]
    ) {
        self.totalDuration = totalDuration
        self.activeDuration = activeDuration
        self.inactiveDuration = inactiveDuration
        self.unclassifiedDuration = unclassifiedDuration
        self.editedCount = editedCount
        self.segmentCount = segmentCount
        self.categoryDurations = categoryDurations
    }

    public var correctionRate: Double {
        guard segmentCount > 0 else {
            return 0
        }
        return Double(editedCount) / Double(segmentCount)
    }

    public func topCategories(limit: Int) -> [ActivityCategoryDuration] {
        categoryDurations
            .map { ActivityCategoryDuration(categoryID: $0.key, duration: $0.value) }
            .sorted {
                if $0.duration == $1.duration {
                    return $0.categoryID.localizedCaseInsensitiveCompare($1.categoryID) == .orderedAscending
                }
                return $0.duration > $1.duration
            }
            .prefix(limit)
            .map { $0 }
    }
}

public struct ActivityRibbonEntry: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var segmentID: UUID
    public var startFraction: Double
    public var widthFraction: Double
    public var categoryID: String
    public var state: ActivityState
    public var appName: String?
    public var duration: TimeInterval

    public init(
        id: UUID = UUID(),
        segmentID: UUID,
        startFraction: Double,
        widthFraction: Double,
        categoryID: String,
        state: ActivityState,
        appName: String?,
        duration: TimeInterval
    ) {
        self.id = id
        self.segmentID = segmentID
        self.startFraction = startFraction
        self.widthFraction = widthFraction
        self.categoryID = categoryID
        self.state = state
        self.appName = appName
        self.duration = duration
    }
}

public enum ActivityDayPresenter {
    public static func summary(for segments: [ActivitySegment], in day: DateInterval) -> ActivityDaySummary {
        var categoryDurations: [String: TimeInterval] = [:]
        var activeDuration: TimeInterval = 0
        var inactiveDuration: TimeInterval = 0
        var unclassifiedDuration: TimeInterval = 0
        var totalDuration: TimeInterval = 0
        var editedCount = 0

        for segment in segments {
            let duration = clippedDuration(of: segment, in: day)
            guard duration > 0 else {
                continue
            }

            totalDuration += duration
            categoryDurations[segment.categoryID, default: 0] += duration

            if segment.state == .inactive || segment.categoryID == CategoryID.inactive.rawValue {
                inactiveDuration += duration
            } else {
                activeDuration += duration
            }

            if segment.categoryID == CategoryID.unclassified.rawValue {
                unclassifiedDuration += duration
            }

            if segment.hasManualOverride {
                editedCount += 1
            }
        }

        return ActivityDaySummary(
            totalDuration: totalDuration,
            activeDuration: activeDuration,
            inactiveDuration: inactiveDuration,
            unclassifiedDuration: unclassifiedDuration,
            editedCount: editedCount,
            segmentCount: segments.count,
            categoryDurations: categoryDurations
        )
    }

    public static func ribbonEntries(for segments: [ActivitySegment], in day: DateInterval) -> [ActivityRibbonEntry] {
        guard day.duration > 0 else {
            return []
        }

        return segments.compactMap { segment in
            let clippedStart = max(segment.start, day.start)
            let clippedEnd = min(segment.end, day.end)
            let duration = clippedEnd.timeIntervalSince(clippedStart)
            guard duration > 0 else {
                return nil
            }

            return ActivityRibbonEntry(
                segmentID: segment.id,
                startFraction: clippedStart.timeIntervalSince(day.start) / day.duration,
                widthFraction: duration / day.duration,
                categoryID: segment.categoryID,
                state: segment.state,
                appName: segment.appName,
                duration: duration
            )
        }
    }

    private static func clippedDuration(of segment: ActivitySegment, in day: DateInterval) -> TimeInterval {
        let clippedStart = max(segment.start, day.start)
        let clippedEnd = min(segment.end, day.end)
        return max(0, clippedEnd.timeIntervalSince(clippedStart))
    }
}
