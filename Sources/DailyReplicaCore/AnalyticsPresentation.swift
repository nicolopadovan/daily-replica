import Foundation

public enum AnalyticsPeriod: String, CaseIterable, Identifiable, Sendable {
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

    public var calendarComponent: Calendar.Component {
        switch self {
        case .day:
            return .day
        case .week:
            return .weekOfYear
        case .month:
            return .month
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

public struct AnalyticsFilter: Equatable, Sendable {
    public var categoryID: String?
    public var contextID: UUID?
    public var appIdentifier: String?
    public var websiteHost: String?

    public init(
        categoryID: String? = nil,
        contextID: UUID? = nil,
        appIdentifier: String? = nil,
        websiteHost: String? = nil
    ) {
        self.categoryID = categoryID
        self.contextID = contextID
        self.appIdentifier = appIdentifier
        self.websiteHost = websiteHost
    }

    public static let all = AnalyticsFilter()

    public var isEmpty: Bool {
        categoryID == nil && contextID == nil && appIdentifier == nil && websiteHost == nil
    }

    public var hasSelection: Bool {
        !isEmpty
    }
}

public struct AnalyticsCalendarDay: Equatable, Sendable {
    public var id: Date { date }
    public var date: Date
    public var totalDuration: TimeInterval
    public var activeDuration: TimeInterval
    public var inactiveDuration: TimeInterval
    public var unclassifiedDuration: TimeInterval

    public init(
        date: Date,
        totalDuration: TimeInterval,
        activeDuration: TimeInterval,
        inactiveDuration: TimeInterval,
        unclassifiedDuration: TimeInterval
    ) {
        self.date = date
        self.totalDuration = totalDuration
        self.activeDuration = activeDuration
        self.inactiveDuration = inactiveDuration
        self.unclassifiedDuration = unclassifiedDuration
    }
}

public struct AnalyticsChartPoint: Equatable, Sendable, Identifiable {
    public var id: Date { date }
    public var date: Date
    public var activeDuration: TimeInterval
    public var inactiveDuration: TimeInterval
    public var unclassifiedDuration: TimeInterval

    public init(date: Date, activeDuration: TimeInterval, inactiveDuration: TimeInterval, unclassifiedDuration: TimeInterval) {
        self.date = date
        self.activeDuration = activeDuration
        self.inactiveDuration = inactiveDuration
        self.unclassifiedDuration = unclassifiedDuration
    }
}

public struct AnalyticsBreakdown: Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var duration: TimeInterval

    public init(id: String, title: String, duration: TimeInterval) {
        self.id = id
        self.title = title
        self.duration = duration
    }
}

public struct AnalyticsReport: Equatable, Sendable {
    public var period: AnalyticsPeriod
    public var interval: DateInterval
    public var drilldownInterval: DateInterval?
    public var totalDuration: TimeInterval
    public var activeDuration: TimeInterval
    public var inactiveDuration: TimeInterval
    public var unclassifiedDuration: TimeInterval
    public var categoryItems: [AnalyticsBreakdown]
    public var projectItems: [AnalyticsBreakdown]
    public var appItems: [AnalyticsBreakdown]
    public var websiteItems: [AnalyticsBreakdown]
    public var dailyPoints: [AnalyticsChartPoint]
    public var calendarDays: [AnalyticsCalendarDay]
    public var filter: AnalyticsFilter

    public init(
        period: AnalyticsPeriod,
        interval: DateInterval,
        drilldownInterval: DateInterval? = nil,
        totalDuration: TimeInterval,
        activeDuration: TimeInterval,
        inactiveDuration: TimeInterval,
        unclassifiedDuration: TimeInterval,
        categoryItems: [AnalyticsBreakdown],
        projectItems: [AnalyticsBreakdown],
        appItems: [AnalyticsBreakdown],
        websiteItems: [AnalyticsBreakdown],
        dailyPoints: [AnalyticsChartPoint],
        calendarDays: [AnalyticsCalendarDay],
        filter: AnalyticsFilter = .all
    ) {
        self.period = period
        self.interval = interval
        self.drilldownInterval = drilldownInterval
        self.totalDuration = totalDuration
        self.activeDuration = activeDuration
        self.inactiveDuration = inactiveDuration
        self.unclassifiedDuration = unclassifiedDuration
        self.categoryItems = categoryItems
        self.projectItems = projectItems
        self.appItems = appItems
        self.websiteItems = websiteItems
        self.dailyPoints = dailyPoints
        self.calendarDays = calendarDays
        self.filter = filter
    }

    public static let empty = AnalyticsReport(
        period: .week,
        interval: DateInterval(start: Date(), duration: 60 * 60 * 24),
        totalDuration: 0,
        activeDuration: 0,
        inactiveDuration: 0,
        unclassifiedDuration: 0,
        categoryItems: [],
        projectItems: [],
        appItems: [],
        websiteItems: [],
        dailyPoints: [],
        calendarDays: []
    )

    public var selectedInterval: DateInterval {
        drilldownInterval ?? interval
    }

    public var hasData: Bool {
        totalDuration > 0 || !calendarDays.isEmpty
    }
}

public enum AnalyticsPresenter {
    public static func report(
        for segments: [ActivitySegment],
        sessions: [ProjectSession],
        in interval: DateInterval,
        filter: AnalyticsFilter = .all,
        drilldownDate: Date? = nil,
        period: AnalyticsPeriod = .week,
        calendar: Calendar = .dailyReplica
    ) -> AnalyticsReport {
        let filteredSegments = applyFilter(filter, to: segments)
        let projectSessions = applyFilter(filter, to: sessions)

        let summary = ActivityDashboardPresenter.summary(
            for: filteredSegments,
            projectSessions: projectSessions,
            in: interval,
            calendar: calendar
        )

        let drilldownInterval = drilldownDate.map { DateInterval.day(containing: $0, calendar: calendar) }
        let drilldownSource = drilldownInterval ?? interval
        let drilldownSegments = filteredSegments.filter { intersects($0, with: drilldownSource) }
        let drilldownSessions = projectSessions.filter { intersects($0, with: drilldownSource) }
        let drilldownSummary = drilldownInterval == nil ? summary : ActivityDashboardPresenter.summary(
            for: drilldownSegments,
            projectSessions: drilldownSessions,
            in: drilldownSource,
            calendar: calendar
        )

        return AnalyticsReport(
            period: period,
            interval: interval,
            drilldownInterval: drilldownInterval,
            totalDuration: drilldownSummary.totalDuration,
            activeDuration: drilldownSummary.activeDuration,
            inactiveDuration: drilldownSummary.inactiveDuration,
            unclassifiedDuration: drilldownSummary.unclassifiedDuration,
            categoryItems: breakdowns(from: drilldownSummary.categoryItems),
            projectItems: breakdowns(from: drilldownSummary.projectItems),
            appItems: breakdowns(from: drilldownSummary.appItems),
            websiteItems: breakdowns(from: drilldownSummary.websiteItems),
            dailyPoints: chartPoints(from: filteredSegments, in: interval, calendar: calendar),
            calendarDays: calendarDays(from: filteredSegments, in: interval, calendar: calendar),
            filter: filter
        )
    }

    private static func breakdowns(from items: [DashboardMetricItem]) -> [AnalyticsBreakdown] {
        items.map { AnalyticsBreakdown(id: $0.id, title: $0.title, duration: $0.duration) }
    }

    private static func chartPoints(
        from segments: [ActivitySegment],
        in interval: DateInterval,
        calendar: Calendar
    ) -> [AnalyticsChartPoint] {
        var points: [AnalyticsChartPoint] = []
        var dayStart = DateInterval.day(containing: interval.start, calendar: calendar).start

        while dayStart < interval.end {
            let dayInterval = DateInterval.day(containing: dayStart, calendar: calendar)
            var total: TimeInterval = 0
            var active: TimeInterval = 0
            var inactive: TimeInterval = 0
            var unclassified: TimeInterval = 0

            for segment in segments {
                let duration = clippedDuration(start: segment.start, end: segment.end, in: dayInterval)
                guard duration > 0 else {
                    continue
                }
                total += duration
                if segment.state == .inactive || segment.categoryID == CategoryID.inactive.rawValue {
                    inactive += duration
                } else {
                    active += duration
                }
                if segment.categoryID == CategoryID.unclassified.rawValue {
                    unclassified += duration
                }
            }

            points.append(
                AnalyticsChartPoint(
                    date: dayStart,
                    activeDuration: active,
                    inactiveDuration: inactive,
                    unclassifiedDuration: unclassified
                )
            )

            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)
            dayStart = nextDay ?? interval.end
        }

        return points
    }

    private static func calendarDays(
        from segments: [ActivitySegment],
        in interval: DateInterval,
        calendar: Calendar
    ) -> [AnalyticsCalendarDay] {
        var days: [AnalyticsCalendarDay] = []
        var dayStart = DateInterval.day(containing: interval.start, calendar: calendar).start

        while dayStart < interval.end {
            let dayInterval = DateInterval.day(containing: dayStart, calendar: calendar)
            var total: TimeInterval = 0
            var active: TimeInterval = 0
            var inactive: TimeInterval = 0
            var unclassified: TimeInterval = 0

            for segment in segments {
                let duration = clippedDuration(start: segment.start, end: segment.end, in: dayInterval)
                guard duration > 0 else {
                    continue
                }
                total += duration
                if segment.state == .inactive || segment.categoryID == CategoryID.inactive.rawValue {
                    inactive += duration
                } else {
                    active += duration
                }
                if segment.categoryID == CategoryID.unclassified.rawValue {
                    unclassified += duration
                }
            }

            days.append(
                AnalyticsCalendarDay(
                    date: dayStart,
                    totalDuration: total,
                    activeDuration: active,
                    inactiveDuration: inactive,
                    unclassifiedDuration: unclassified
                )
            )

            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)
            dayStart = nextDay ?? interval.end
        }

        return days
    }

    private static func applyFilter(_ filter: AnalyticsFilter, to segments: [ActivitySegment]) -> [ActivitySegment] {
        guard filter.hasSelection else {
            return segments
        }

        return segments.filter { segment in
            if let categoryID = filter.categoryID, segment.categoryID != categoryID {
                return false
            }
            if let contextID = filter.contextID, segment.contextID != contextID {
                return false
            }
            if let appIdentifier = filter.appIdentifier,
               segment.appBundleID != appIdentifier,
               segment.appName != appIdentifier {
                return false
            }
            if let websiteHost = filter.websiteHost {
                let segmentHost = segment.urlHost?.lowercased() ?? segment.urlString.flatMap(URL.init(string:))?.host?.lowercased()
                guard segmentHost == websiteHost else {
                    return false
                }
            }
            return true
        }
    }

    private static func applyFilter(_ filter: AnalyticsFilter, to sessions: [ProjectSession]) -> [ProjectSession] {
        guard let contextID = filter.contextID else {
            return sessions
        }
        return sessions.filter { $0.contextID == contextID }
    }

    private static func intersects(_ segment: ActivitySegment, with interval: DateInterval) -> Bool {
        segment.start < interval.end && segment.end >= interval.start
    }

    private static func intersects(_ session: ProjectSession, with interval: DateInterval) -> Bool {
        session.start < interval.end && (session.end ?? .distantFuture) >= interval.start
    }

    private static func clippedDuration(start: Date, end: Date, in interval: DateInterval) -> TimeInterval {
        let clippedStart = max(start, interval.start)
        let clippedEnd = min(end, interval.end)
        return max(0, clippedEnd.timeIntervalSince(clippedStart))
    }
}
