import XCTest
@testable import DailyReplicaCore

final class SQLiteActivityStoreTests: XCTestCase {
    func testPersistsContextsRulesAndSegments() throws {
        let store = try SQLiteActivityStore(path: ":memory:")
        let start = Date(timeIntervalSince1970: 100)
        let createdAt = Date(timeIntervalSince1970: 50)
        let context = ProjectContext(name: "Client Project", defaultCategoryID: CategoryID.work.rawValue, createdAt: createdAt)
        let rule = ClassificationRule(kind: .appBundleID, pattern: "com.apple.dt.Xcode", categoryID: CategoryID.work.rawValue, createdAt: createdAt)
        let segment = ActivitySegment(
            start: start,
            end: start.addingTimeInterval(60),
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode",
            windowTitle: "Daily Replica",
            categoryID: CategoryID.work.rawValue,
            contextID: context.id,
            contextName: context.name,
            createdAt: createdAt,
            updatedAt: createdAt
        )

        try store.upsertContext(context)
        try store.upsertRule(rule)
        try store.upsertSegment(segment)

        let contexts = try store.fetchContexts()
        let rules = try store.fetchRules()
        let segments = try store.fetchSegments(in: DateInterval(start: start, duration: 120))

        XCTAssertEqual(contexts, [context])
        XCTAssertEqual(rules, [rule])
        XCTAssertEqual(segments, [segment])
        XCTAssertEqual(try store.fetchCategories().count, CategoryID.allCases.count)
    }

    func testUpsertSegmentStoresManualOverrideFields() throws {
        let store = try SQLiteActivityStore(path: ":memory:")
        let context = ProjectContext(name: "Break", defaultCategoryID: CategoryID.videogames.rawValue)
        let start = Date(timeIntervalSince1970: 100)
        let segment = ActivitySegment(
            start: start,
            end: start.addingTimeInterval(60),
            state: .active,
            appBundleID: "com.valvesoftware.steam",
            appName: "Steam",
            categoryID: CategoryID.videogames.rawValue
        ).applyingManualEdit(categoryID: CategoryID.personal.rawValue, context: context, note: "Actually testing")

        try store.upsertSegment(segment)

        let segments = try store.fetchSegments(in: DateInterval(start: start, duration: 120))
        XCTAssertEqual(segments.first?.manualCategoryID, CategoryID.personal.rawValue)
        XCTAssertEqual(segments.first?.manualContextID, context.id)
        XCTAssertEqual(segments.first?.manualNote, "Actually testing")
    }

    func testDeleteSegmentRemovesItFromFetchResults() throws {
        let store = try SQLiteActivityStore(path: ":memory:")
        let start = Date(timeIntervalSince1970: 100)
        let createdAt = Date(timeIntervalSince1970: 50)
        let first = ActivitySegment(
            start: start,
            end: start.addingTimeInterval(60),
            state: .active,
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let second = ActivitySegment(
            start: start.addingTimeInterval(60),
            end: start.addingTimeInterval(120),
            state: .active,
            appName: "Safari",
            categoryID: CategoryID.browsing.rawValue,
            createdAt: createdAt,
            updatedAt: createdAt
        )

        try store.upsertSegment(first)
        try store.upsertSegment(second)
        try store.deleteSegment(id: first.id)

        let segments = try store.fetchSegments(in: DateInterval(start: start, duration: 120))
        XCTAssertEqual(segments, [second])
    }

    func testPersistsFetchesAndUpdatesProjectSessions() throws {
        let store = try SQLiteActivityStore(path: ":memory:")
        let context = ProjectContext(name: "Client", defaultCategoryID: CategoryID.work.rawValue)
        let start = Date(timeIntervalSince1970: 100)
        let createdAt = Date(timeIntervalSince1970: 90)
        var session = ProjectSession(
            contextID: context.id,
            contextName: context.name,
            start: start,
            createdAt: createdAt,
            updatedAt: createdAt
        )

        try store.upsertProjectSession(session)

        XCTAssertEqual(try store.fetchOpenProjectSession(), session)
        XCTAssertEqual(
            try store.fetchProjectSessions(in: DateInterval(start: start.addingTimeInterval(-10), duration: 20)),
            [session]
        )

        session.end = start.addingTimeInterval(120)
        session.updatedAt = session.end!
        try store.upsertProjectSession(session)

        XCTAssertNil(try store.fetchOpenProjectSession())
        XCTAssertEqual(
            try store.fetchProjectSessions(in: DateInterval(start: start.addingTimeInterval(60), duration: 120)),
            [session]
        )
        XCTAssertEqual(
            try store.fetchProjectSessions(in: DateInterval(start: start.addingTimeInterval(130), duration: 60)),
            []
        )
    }
}
