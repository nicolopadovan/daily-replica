import XCTest
@testable import DailyReplicaCore

final class SmartPromptEngineTests: XCTestCase {
    func testUnclassifiedPromptAfterTwoMinutesAndCooldown() {
        let start = Date(timeIntervalSince1970: 100)
        let segment = ActivitySegment(
            start: start,
            end: start.addingTimeInterval(120),
            state: .active,
            appBundleID: "com.example.NewApp",
            appName: "New App",
            categoryID: CategoryID.unclassified.rawValue
        )
        var engine = SmartPromptEngine()

        let prompt = engine.evaluate(segment: segment, currentContext: nil, now: start.addingTimeInterval(120))

        XCTAssertEqual(prompt?.kind, .unclassifiedActivity)
        XCTAssertEqual(prompt?.key, "unclassified:com.example.NewApp")

        engine.recordPrompt(prompt!, at: start.addingTimeInterval(120))
        let suppressed = engine.evaluate(segment: segment, currentContext: nil, now: start.addingTimeInterval(200))
        XCTAssertNil(suppressed)

        let afterCooldown = engine.evaluate(segment: segment, currentContext: nil, now: start.addingTimeInterval(2_000))
        XCTAssertEqual(afterCooldown?.kind, .unclassifiedActivity)
    }

    func testMismatchPromptAfterFiveMinutes() {
        let context = ProjectContext(
            id: UUID(),
            name: "Client Project",
            defaultCategoryID: CategoryID.work.rawValue
        )
        let start = Date(timeIntervalSince1970: 100)
        let segment = ActivitySegment(
            start: start,
            end: start.addingTimeInterval(301),
            state: .active,
            appBundleID: "com.valvesoftware.steam",
            appName: "Steam",
            categoryID: CategoryID.videogames.rawValue,
            contextID: context.id,
            contextName: context.name
        )
        var engine = SmartPromptEngine()

        let prompt = engine.evaluate(segment: segment, currentContext: context, now: start.addingTimeInterval(301))

        XCTAssertEqual(prompt?.kind, .categoryMismatch)
        XCTAssertEqual(prompt?.suggestedCategoryID, CategoryID.work.rawValue)
    }

    func testNoMismatchPromptWhenCategoryMatchesContext() {
        let context = ProjectContext(
            id: UUID(),
            name: "Client Project",
            defaultCategoryID: CategoryID.work.rawValue
        )
        let start = Date(timeIntervalSince1970: 100)
        let segment = ActivitySegment(
            start: start,
            end: start.addingTimeInterval(500),
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode",
            categoryID: CategoryID.work.rawValue,
            contextID: context.id,
            contextName: context.name
        )
        var engine = SmartPromptEngine()

        let prompt = engine.evaluate(segment: segment, currentContext: context, now: start.addingTimeInterval(500))

        XCTAssertNil(prompt)
    }
}
