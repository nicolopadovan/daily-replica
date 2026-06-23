import XCTest
@testable import DailyReplicaCore

final class ActivityDashboardPresentationTests: XCTestCase {
    func testDashboardPeriodIntervals() {
        let calendar = Self.calendar
        let date = Self.date(year: 2026, month: 6, day: 23, hour: 12)

        XCTAssertEqual(DashboardPeriod.day.interval(containing: date, calendar: calendar).start, Self.date(year: 2026, month: 6, day: 23))
        XCTAssertEqual(DashboardPeriod.week.interval(containing: date, calendar: calendar).start, Self.date(year: 2026, month: 6, day: 22))
        XCTAssertEqual(DashboardPeriod.month.interval(containing: date, calendar: calendar).start, Self.date(year: 2026, month: 6, day: 1))
    }

    func testSummaryAggregatesCategoryProjectAppAndWebsiteTime() {
        let calendar = Self.calendar
        let interval = DashboardPeriod.day.interval(containing: Self.date(year: 2026, month: 6, day: 23), calendar: calendar)
        let contextID = UUID()
        let segments = [
            ActivitySegment(
                start: interval.start.addingTimeInterval(60),
                end: interval.start.addingTimeInterval(360),
                state: .active,
                appBundleID: "com.apple.dt.Xcode",
                appName: "Xcode",
                categoryID: CategoryID.work.rawValue,
                contextID: contextID,
                contextName: "Daily Replica"
            ),
            ActivitySegment(
                start: interval.start.addingTimeInterval(360),
                end: interval.start.addingTimeInterval(660),
                state: .active,
                appBundleID: "com.google.Chrome",
                appName: "Chrome",
                urlString: "https://github.com/nicolopadovan/daily-replica",
                categoryID: CategoryID.work.rawValue,
                contextID: contextID,
                contextName: "Daily Replica"
            ),
            ActivitySegment(
                start: interval.start.addingTimeInterval(660),
                end: interval.start.addingTimeInterval(960),
                state: .active,
                appBundleID: "com.valvesoftware.steam",
                appName: "Steam",
                categoryID: CategoryID.videogames.rawValue
            )
        ]
        let sessions = [
            ProjectSession(
                contextID: contextID,
                contextName: "Daily Replica",
                start: interval.start.addingTimeInterval(30),
                end: interval.start.addingTimeInterval(630)
            )
        ]

        let summary = ActivityDashboardPresenter.summary(
            for: segments,
            projectSessions: sessions,
            in: interval,
            calendar: calendar
        )

        XCTAssertEqual(summary.totalDuration, 900)
        XCTAssertEqual(summary.categoryDurations[CategoryID.work.rawValue], 600)
        XCTAssertEqual(summary.projectItems.first?.title, "Daily Replica")
        XCTAssertEqual(summary.projectItems.first?.duration, 600)
        XCTAssertEqual(summary.appItems.map(\.title), ["Chrome", "Steam", "Xcode"])
        XCTAssertEqual(summary.websiteItems.first?.title, "github.com")
        XCTAssertEqual(summary.websiteItems.first?.duration, 300)
    }

    func testSummaryHighlightsFocusedDistractionAndUnclassifiedTime() {
        let calendar = Self.calendar
        let interval = DashboardPeriod.day.interval(containing: Self.date(year: 2026, month: 6, day: 23), calendar: calendar)
        let segments = [
            ActivitySegment(
                start: interval.start,
                end: interval.start.addingTimeInterval(120),
                state: .active,
                appName: "Xcode",
                categoryID: CategoryID.work.rawValue
            ),
            ActivitySegment(
                start: interval.start.addingTimeInterval(120),
                end: interval.start.addingTimeInterval(240),
                state: .active,
                appName: "YouTube",
                categoryID: CategoryID.media.rawValue
            ),
            ActivitySegment(
                start: interval.start.addingTimeInterval(240),
                end: interval.start.addingTimeInterval(300),
                state: .active,
                appName: "Unknown",
                categoryID: CategoryID.unclassified.rawValue
            )
        ]

        let summary = ActivityDashboardPresenter.summary(
            for: segments,
            projectSessions: [],
            in: interval,
            calendar: calendar
        )

        XCTAssertEqual(summary.focusedWorkDuration, 120)
        XCTAssertEqual(summary.distractionDuration, 120)
        XCTAssertEqual(summary.unclassifiedDuration, 60)
        XCTAssertEqual(summary.dailyTotals.count, 1)
        XCTAssertEqual(summary.dailyTotals.first?.totalDuration, 300)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 2
        return calendar
    }

    private static func date(year: Int, month: Int, day: Int, hour: Int = 0) -> Date {
        DateComponents(calendar: calendar, timeZone: TimeZone(secondsFromGMT: 0), year: year, month: month, day: day, hour: hour).date!
    }
}
