import XCTest
@testable import DailyReplicaCore

final class ActivityDayPresentationTests: XCTestCase {
    func testSummaryTotalsEmptyDay() {
        let day = DateInterval(start: Date(timeIntervalSince1970: 0), duration: 24 * 60 * 60)

        let summary = ActivityDayPresenter.summary(for: [], in: day)

        XCTAssertEqual(summary.segmentCount, 0)
        XCTAssertEqual(summary.totalDuration, 0)
        XCTAssertEqual(summary.activeDuration, 0)
        XCTAssertEqual(summary.inactiveDuration, 0)
        XCTAssertEqual(summary.unclassifiedDuration, 0)
        XCTAssertEqual(summary.editedCount, 0)
        XCTAssertEqual(summary.categoryDurations, [:])
    }

    func testSummaryTotalsSegmentsByCategory() {
        let dayStart = Date(timeIntervalSince1970: 0)
        let day = DateInterval(start: dayStart, duration: 24 * 60 * 60)
        let edited = ActivitySegment(
            start: dayStart.addingTimeInterval(60),
            end: dayStart.addingTimeInterval(180),
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue
        ).applyingManualEdit(categoryID: CategoryID.work.rawValue, note: "Client work")
        let inactive = ActivitySegment(
            start: dayStart.addingTimeInterval(180),
            end: dayStart.addingTimeInterval(240),
            state: .inactive,
            categoryID: CategoryID.inactive.rawValue
        )
        let unclassified = ActivitySegment(
            start: dayStart.addingTimeInterval(240),
            end: dayStart.addingTimeInterval(300),
            state: .active,
            appBundleID: "com.example.Unknown",
            appName: "Unknown",
            categoryID: CategoryID.unclassified.rawValue
        )

        let summary = ActivityDayPresenter.summary(for: [edited, inactive, unclassified], in: day)

        XCTAssertEqual(summary.segmentCount, 3)
        XCTAssertEqual(summary.totalDuration, 240)
        XCTAssertEqual(summary.activeDuration, 180)
        XCTAssertEqual(summary.inactiveDuration, 60)
        XCTAssertEqual(summary.unclassifiedDuration, 60)
        XCTAssertEqual(summary.editedCount, 1)
        XCTAssertEqual(summary.categoryDurations[CategoryID.work.rawValue], 120)
        XCTAssertEqual(summary.categoryDurations[CategoryID.inactive.rawValue], 60)
        XCTAssertEqual(summary.categoryDurations[CategoryID.unclassified.rawValue], 60)
    }

    func testRibbonClampsToDayBoundsAndPreservesFractions() {
        let dayStart = Date(timeIntervalSince1970: 0)
        let day = DateInterval(start: dayStart, duration: 100)
        let beforeStart = ActivitySegment(
            start: dayStart.addingTimeInterval(-20),
            end: dayStart.addingTimeInterval(20),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue
        )
        let afterEnd = ActivitySegment(
            start: dayStart.addingTimeInterval(80),
            end: dayStart.addingTimeInterval(120),
            state: .inactive,
            categoryID: CategoryID.inactive.rawValue
        )

        let ribbon = ActivityDayPresenter.ribbonEntries(for: [beforeStart, afterEnd], in: day)

        XCTAssertEqual(ribbon.count, 2)
        XCTAssertEqual(ribbon[0].startFraction, 0, accuracy: 0.0001)
        XCTAssertEqual(ribbon[0].widthFraction, 0.2, accuracy: 0.0001)
        XCTAssertEqual(ribbon[0].categoryID, CategoryID.work.rawValue)
        XCTAssertEqual(ribbon[1].startFraction, 0.8, accuracy: 0.0001)
        XCTAssertEqual(ribbon[1].widthFraction, 0.2, accuracy: 0.0001)
        XCTAssertEqual(ribbon[1].state, .inactive)
    }

    func testTopCategoriesSortByDurationThenName() {
        let summary = ActivityDaySummary(
            totalDuration: 120,
            activeDuration: 120,
            inactiveDuration: 0,
            unclassifiedDuration: 0,
            editedCount: 0,
            segmentCount: 2,
            categoryDurations: [
                "zeta": 30,
                "alpha": 60,
                "beta": 60
            ]
        )

        XCTAssertEqual(summary.topCategories(limit: 2).map(\.categoryID), ["alpha", "beta"])
    }
}
