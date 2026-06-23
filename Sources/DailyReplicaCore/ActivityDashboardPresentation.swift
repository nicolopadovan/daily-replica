import Foundation

public enum DashboardPeriod: String, CaseIterable, Identifiable, Sendable {
    case day
    case week
    case month

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .day: "Day"
        case .week: "Week"
        case .month: "Month"
        }
    }

    public func interval(containing date: Date, calendar: Calendar = .dailyReplica) -> DateInterval {
        switch self {
        case .day:
            return DateInterval.day(containing: date, calendar: calendar)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval.day(containing: date, calendar: calendar)
        case .month:
            return calendar.dateInterval(of: .month, for: date) ?? DateInterval.day(containing: date, calendar: calendar)
        }
    }
}

public struct DashboardMetricItem: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var duration: TimeInterval

    public init(id: String, title: String, duration: TimeInterval) {
        self.id = id
        self.title = title
        self.duration = duration
    }
}

public struct DashboardDailyTotal: Equatable, Identifiable, Sendable {
    public var id: Date { date }
    public var date: Date
    public var totalDuration: TimeInterval
    public var activeDuration: TimeInterval
    public var unclassifiedDuration: TimeInterval

    public init(
        date: Date,
        totalDuration: TimeInterval,
        activeDuration: TimeInterval,
        unclassifiedDuration: TimeInterval
    ) {
        self.date = date
        self.totalDuration = totalDuration
        self.activeDuration = activeDuration
        self.unclassifiedDuration = unclassifiedDuration
    }
}

public struct ActivityDashboardSummary: Equatable, Sendable {
    public var totalDuration: TimeInterval
    public var activeDuration: TimeInterval
    public var inactiveDuration: TimeInterval
    public var focusedWorkDuration: TimeInterval
    public var distractionDuration: TimeInterval
    public var unclassifiedDuration: TimeInterval
    public var categoryDurations: [String: TimeInterval]
    public var categoryItems: [DashboardMetricItem]
    public var projectItems: [DashboardMetricItem]
    public var appItems: [DashboardMetricItem]
    public var websiteItems: [DashboardMetricItem]
    public var dailyTotals: [DashboardDailyTotal]

    public init(
        totalDuration: TimeInterval,
        activeDuration: TimeInterval,
        inactiveDuration: TimeInterval,
        focusedWorkDuration: TimeInterval,
        distractionDuration: TimeInterval,
        unclassifiedDuration: TimeInterval,
        categoryDurations: [String: TimeInterval],
        categoryItems: [DashboardMetricItem],
        projectItems: [DashboardMetricItem],
        appItems: [DashboardMetricItem],
        websiteItems: [DashboardMetricItem],
        dailyTotals: [DashboardDailyTotal]
    ) {
        self.totalDuration = totalDuration
        self.activeDuration = activeDuration
        self.inactiveDuration = inactiveDuration
        self.focusedWorkDuration = focusedWorkDuration
        self.distractionDuration = distractionDuration
        self.unclassifiedDuration = unclassifiedDuration
        self.categoryDurations = categoryDurations
        self.categoryItems = categoryItems
        self.projectItems = projectItems
        self.appItems = appItems
        self.websiteItems = websiteItems
        self.dailyTotals = dailyTotals
    }
}

public enum ActivityDashboardPresenter {
    public static func summary(
        for segments: [ActivitySegment],
        projectSessions: [ProjectSession],
        in interval: DateInterval,
        calendar: Calendar = .dailyReplica
    ) -> ActivityDashboardSummary {
        var totalDuration: TimeInterval = 0
        var activeDuration: TimeInterval = 0
        var inactiveDuration: TimeInterval = 0
        var focusedWorkDuration: TimeInterval = 0
        var distractionDuration: TimeInterval = 0
        var unclassifiedDuration: TimeInterval = 0
        var categoryDurations: [String: TimeInterval] = [:]
        var appDurations: [String: (title: String, duration: TimeInterval)] = [:]
        var websiteDurations: [String: TimeInterval] = [:]
        var fallbackProjectDurations: [String: (title: String, duration: TimeInterval)] = [:]

        for segment in segments {
            let duration = clippedDuration(start: segment.start, end: segment.end, in: interval)
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

            if segment.categoryID == CategoryID.work.rawValue {
                focusedWorkDuration += duration
            }
            if segment.categoryID == CategoryID.media.rawValue || segment.categoryID == CategoryID.videogames.rawValue {
                distractionDuration += duration
            }
            if segment.categoryID == CategoryID.unclassified.rawValue {
                unclassifiedDuration += duration
            }

            if let appID = segment.appBundleID ?? segment.appName {
                let title = segment.appName ?? appID
                appDurations[appID] = (title, (appDurations[appID]?.duration ?? 0) + duration)
            }
            if let host = segment.urlHost ?? segment.urlString.flatMap({ URL(string: $0)?.host?.lowercased() }) {
                websiteDurations[host, default: 0] += duration
            }
            if let contextID = segment.contextID, let contextName = segment.contextName {
                let id = contextID.uuidString
                fallbackProjectDurations[id] = (contextName, (fallbackProjectDurations[id]?.duration ?? 0) + duration)
            }
        }

        let projectItems = projectItems(from: projectSessions, fallback: fallbackProjectDurations, interval: interval)

        return ActivityDashboardSummary(
            totalDuration: totalDuration,
            activeDuration: activeDuration,
            inactiveDuration: inactiveDuration,
            focusedWorkDuration: focusedWorkDuration,
            distractionDuration: distractionDuration,
            unclassifiedDuration: unclassifiedDuration,
            categoryDurations: categoryDurations,
            categoryItems: metricItems(fromDurations: categoryDurations),
            projectItems: projectItems,
            appItems: metricItems(from: appDurations),
            websiteItems: metricItems(fromDurations: websiteDurations),
            dailyTotals: dailyTotals(for: segments, in: interval, calendar: calendar)
        )
    }

    private static func projectItems(
        from sessions: [ProjectSession],
        fallback: [String: (title: String, duration: TimeInterval)],
        interval: DateInterval
    ) -> [DashboardMetricItem] {
        guard !sessions.isEmpty else {
            return metricItems(from: fallback)
        }

        var durations: [String: (title: String, duration: TimeInterval)] = [:]
        for session in sessions {
            let duration = clippedDuration(start: session.start, end: session.end ?? Date(), in: interval)
            guard duration > 0 else {
                continue
            }
            let id = session.contextID.uuidString
            durations[id] = (session.contextName, (durations[id]?.duration ?? 0) + duration)
        }
        return metricItems(from: durations)
    }

    private static func dailyTotals(
        for segments: [ActivitySegment],
        in interval: DateInterval,
        calendar: Calendar
    ) -> [DashboardDailyTotal] {
        var totals: [DashboardDailyTotal] = []
        var dayStart = DateInterval.day(containing: interval.start, calendar: calendar).start

        while dayStart < interval.end {
            let day = DateInterval.day(containing: dayStart, calendar: calendar)
            var totalDuration: TimeInterval = 0
            var activeDuration: TimeInterval = 0
            var unclassifiedDuration: TimeInterval = 0

            for segment in segments {
                let duration = clippedDuration(start: segment.start, end: segment.end, in: day)
                guard duration > 0 else {
                    continue
                }
                totalDuration += duration
                if segment.state == .active && segment.categoryID != CategoryID.inactive.rawValue {
                    activeDuration += duration
                }
                if segment.categoryID == CategoryID.unclassified.rawValue {
                    unclassifiedDuration += duration
                }
            }

            totals.append(
                DashboardDailyTotal(
                    date: dayStart,
                    totalDuration: totalDuration,
                    activeDuration: activeDuration,
                    unclassifiedDuration: unclassifiedDuration
                )
            )
            dayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? interval.end
        }

        return totals
    }

    private static func metricItems(from values: [String: (title: String, duration: TimeInterval)]) -> [DashboardMetricItem] {
        values
            .map { DashboardMetricItem(id: $0.key, title: $0.value.title, duration: $0.value.duration) }
            .filter { $0.duration > 0 }
            .sorted {
                if $0.duration == $1.duration {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.duration > $1.duration
            }
    }

    private static func metricItems(fromDurations values: [String: TimeInterval]) -> [DashboardMetricItem] {
        values
            .map { DashboardMetricItem(id: $0.key, title: $0.key, duration: $0.value) }
            .filter { $0.duration > 0 }
            .sorted {
                if $0.duration == $1.duration {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.duration > $1.duration
            }
    }

    private static func clippedDuration(start: Date, end: Date, in interval: DateInterval) -> TimeInterval {
        let clippedStart = max(start, interval.start)
        let clippedEnd = min(end, interval.end)
        return max(0, clippedEnd.timeIntervalSince(clippedStart))
    }
}
