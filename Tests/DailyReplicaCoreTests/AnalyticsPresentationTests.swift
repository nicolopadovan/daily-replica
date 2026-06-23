import XCTest
@testable import DailyReplicaCore

final class AnalyticsPresentationTests: XCTestCase {
    func testWeeklyReportAggregatesDailyTotals() {
        let calendar = Self.calendar
        let date = Self.date(year: 2026, month: 6, day: 23, hour: 10)
        let interval = AnalyticsPeriod.week.interval(containing: date, calendar: calendar)
        let weekStart = interval.start
        let context = ProjectContext(name: "Daily Replica", defaultCategoryID: CategoryID.work.rawValue)

        let segments = [
            ActivitySegment(
                start: weekStart.addingTimeInterval(3_600),
                end: weekStart.addingTimeInterval(3_600 + 1_200),
                state: .active,
                appBundleID: "com.example.work",
                appName: "Work App",
                categoryID: CategoryID.work.rawValue,
                contextID: context.id,
                contextName: context.name
            ),
            ActivitySegment(
                start: weekStart.addingTimeInterval(2_400),
                end: weekStart.addingTimeInterval(2_700),
                state: .inactive,
                appBundleID: "com.example.break",
                appName: "Break App",
                categoryID: CategoryID.inactive.rawValue
            ),
            ActivitySegment(
                start: calendar.date(byAdding: .day, value: 2, to: weekStart)!.addingTimeInterval(600),
                end: calendar.date(byAdding: .day, value: 2, to: weekStart)!.addingTimeInterval(900),
                state: .active,
                appBundleID: "com.example.social",
                appName: "Social App",
                categoryID: CategoryID.media.rawValue
            ),
            ActivitySegment(
                start: calendar.date(byAdding: .day, value: 4, to: weekStart)!.addingTimeInterval(600),
                end: calendar.date(byAdding: .day, value: 4, to: weekStart)!.addingTimeInterval(1_020),
                state: .active,
                appBundleID: "com.example.un",
                appName: "Other App",
                categoryID: CategoryID.unclassified.rawValue
            )
        ]
        let sessions = [
            ProjectSession(
                contextID: context.id,
                contextName: context.name,
                start: weekStart.addingTimeInterval(180),
                end: weekStart.addingTimeInterval(4_320)
            )
        ]

        let report = AnalyticsPresenter.report(
            for: segments,
            sessions: sessions,
            in: interval,
            period: .week,
            calendar: calendar
        )

        let day0 = report.dailyPoints[0]
        let day2 = report.dailyPoints[2]
        let day4 = report.dailyPoints[4]

        XCTAssertEqual(report.dailyPoints.count, 7)
        XCTAssertEqual(report.totalDuration, 3_120)
        XCTAssertEqual(report.activeDuration, 2_820)
        XCTAssertEqual(report.inactiveDuration, 300)
        XCTAssertEqual(report.unclassifiedDuration, 420)
        XCTAssertEqual(day0.activeDuration, 1_200)
        XCTAssertEqual(day0.inactiveDuration, 300)
        XCTAssertEqual(day2.activeDuration, 300)
        XCTAssertEqual(day4.unclassifiedDuration, 420)

        let categoryDurations = Dictionary(uniqueKeysWithValues: report.categoryItems.map { ($0.id, $0.duration) })
        XCTAssertEqual(categoryDurations[CategoryID.work.rawValue], 1_200)
        XCTAssertEqual(categoryDurations[CategoryID.inactive.rawValue], 300)
        XCTAssertEqual(categoryDurations[CategoryID.media.rawValue], 300)
        XCTAssertEqual(categoryDurations[CategoryID.unclassified.rawValue], 420)
        XCTAssertEqual(report.projectItems.first?.duration, 4_140)
    }

    func testMonthCalendarContainsOneBucketPerVisibleDay() {
        let calendar = Self.calendar
        let interval = AnalyticsPeriod.month.interval(containing: Self.date(year: 2026, month: 6, day: 15), calendar: calendar)
        let monthStart = interval.start

        let segments = [
            ActivitySegment(
                start: monthStart.addingTimeInterval(600),
                end: monthStart.addingTimeInterval(900),
                state: .active,
                appBundleID: "com.apple.dt.Xcode",
                appName: "Xcode",
                categoryID: CategoryID.work.rawValue
            ),
            ActivitySegment(
                start: monthStart.addingTimeInterval(9 * 24 * 3_600 + 180),
                end: monthStart.addingTimeInterval(9 * 24 * 3_600 + 480),
                state: .active,
                appName: "Slack",
                categoryID: CategoryID.communication.rawValue
            )
        ]

        let report = AnalyticsPresenter.report(
            for: segments,
            sessions: [],
            in: interval,
            period: .month,
            calendar: calendar
        )

        XCTAssertEqual(report.calendarDays.count, 30)
        XCTAssertEqual(report.calendarDays.first?.date, monthStart)
        XCTAssertEqual(report.calendarDays.last?.date, monthStart.addingTimeInterval(29 * 24 * 3_600))
        XCTAssertEqual(report.calendarDays[0].totalDuration, 300)
        XCTAssertEqual(report.calendarDays[0].activeDuration, 300)
        XCTAssertEqual(report.calendarDays[9].totalDuration, 300)
    }

    func testFiltersRecomputeCategoryProjectAppAndWebsiteBreakdowns() {
        let calendar = Self.calendar
        let interval = AnalyticsPeriod.day.interval(containing: Self.date(year: 2026, month: 6, day: 23, hour: 10), calendar: calendar)
        let dayStart = interval.start
        let contextA = ProjectContext(name: "Alpha", defaultCategoryID: CategoryID.work.rawValue)
        let contextB = ProjectContext(name: "Beta", defaultCategoryID: CategoryID.personal.rawValue)
        let contextFilter = AnalyticsFilter(contextID: contextA.id)

        let segments = [
            ActivitySegment(
                start: dayStart.addingTimeInterval(60),
                end: dayStart.addingTimeInterval(360),
                state: .active,
                appBundleID: "com.example.work",
                appName: "Xcode",
                urlHost: "github.com",
                categoryID: CategoryID.work.rawValue,
                contextID: contextA.id,
                contextName: contextA.name
            ),
            ActivitySegment(
                start: dayStart.addingTimeInterval(420),
                end: dayStart.addingTimeInterval(1_080),
                state: .active,
                appBundleID: "com.example.chat",
                appName: "Slack",
                urlHost: "slack.com",
                categoryID: CategoryID.communication.rawValue,
                contextID: contextB.id,
                contextName: contextB.name
            ),
            ActivitySegment(
                start: dayStart.addingTimeInterval(1_140),
                end: dayStart.addingTimeInterval(1_380),
                state: .active,
                appBundleID: "com.example.chat",
                appName: "Slack",
                urlHost: "slack.com",
                categoryID: CategoryID.communication.rawValue,
                contextID: contextA.id,
                contextName: contextA.name
            )
        ]
        let sessions = [
            ProjectSession(
                contextID: contextA.id,
                contextName: contextA.name,
                start: dayStart.addingTimeInterval(120),
                end: dayStart.addingTimeInterval(1_000)
            ),
            ProjectSession(
                contextID: contextB.id,
                contextName: contextB.name,
                start: dayStart.addingTimeInterval(1_020),
                end: dayStart.addingTimeInterval(1_800)
            )
        ]

        let report = AnalyticsPresenter.report(
            for: segments,
            sessions: sessions,
            in: interval,
            period: .day,
            calendar: calendar
        )

        let allCategories = Dictionary(uniqueKeysWithValues: report.categoryItems.map { ($0.id, $0.duration) })
        XCTAssertEqual(allCategories[CategoryID.work.rawValue], 300)
        XCTAssertEqual(allCategories[CategoryID.communication.rawValue], 960)
        XCTAssertEqual(report.projectItems.first(where: { $0.id == contextA.id.uuidString })?.duration, 880)
        XCTAssertEqual(report.websiteItems.first(where: { $0.id == "github.com" })?.duration, 300)
        XCTAssertEqual(report.websiteItems.first(where: { $0.id == "slack.com" })?.duration, 960)

        let byCategory = AnalyticsPresenter.report(
            for: segments,
            sessions: sessions,
            in: interval,
            filter: AnalyticsFilter(categoryID: CategoryID.communication.rawValue),
            period: .day,
            calendar: calendar
        )
        XCTAssertEqual(byCategory.categoryItems.count, 1)
        XCTAssertEqual(byCategory.categoryItems.first?.duration, 960)
        XCTAssertEqual(byCategory.appItems.first(where: { $0.id == "com.example.chat" })?.duration, 960)

        let byContext = AnalyticsPresenter.report(
            for: segments,
            sessions: sessions,
            in: interval,
            filter: contextFilter,
            period: .day,
            calendar: calendar
        )
        XCTAssertEqual(byContext.projectItems.first(where: { $0.id == contextA.id.uuidString })?.duration, 880)
        XCTAssertEqual(byContext.categoryItems.first(where: { $0.id == CategoryID.work.rawValue })?.duration, 300)

        let byWebsite = AnalyticsPresenter.report(
            for: segments,
            sessions: sessions,
            in: interval,
            filter: AnalyticsFilter(websiteHost: "slack.com"),
            period: .day,
            calendar: calendar
        )
        XCTAssertEqual(byWebsite.websiteItems.first?.duration, 960)
        XCTAssertEqual(byWebsite.appItems.map(\.id), ["com.example.chat"])
    }

    func testEmptyIntervalReturnsEmptyReportData() {
        let calendar = Self.calendar
        let interval = AnalyticsPeriod.day.interval(containing: Self.date(year: 2026, month: 6, day: 23), calendar: calendar)

        let report = AnalyticsPresenter.report(
            for: [],
            sessions: [],
            in: interval,
            period: .day,
            calendar: calendar
        )

        XCTAssertEqual(report.totalDuration, 0)
        XCTAssertEqual(report.activeDuration, 0)
        XCTAssertEqual(report.inactiveDuration, 0)
        XCTAssertEqual(report.unclassifiedDuration, 0)
        XCTAssertTrue(report.categoryItems.isEmpty)
        XCTAssertTrue(report.projectItems.isEmpty)
        XCTAssertTrue(report.appItems.isEmpty)
        XCTAssertTrue(report.websiteItems.isEmpty)
        XCTAssertEqual(report.dailyPoints.count, 1)
        XCTAssertFalse(report.hasData)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day,
            hour: hour
        ).date!
    }
}
