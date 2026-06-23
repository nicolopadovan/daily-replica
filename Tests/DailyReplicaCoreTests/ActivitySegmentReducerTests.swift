import XCTest
@testable import DailyReplicaCore

final class ActivitySegmentReducerTests: XCTestCase {
    func testAdjacentSamplesWithSameClassificationMerge() {
        let reducer = ActivitySegmentReducer()
        let start = Date(timeIntervalSince1970: 100)
        let context = ProjectContext(id: UUID(), name: "Client Project", defaultCategoryID: CategoryID.work.rawValue)
        var segments: [ActivitySegment] = []

        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: start, state: .active, appBundleID: "com.apple.dt.Xcode", appName: "Xcode"),
                categoryID: CategoryID.work.rawValue,
                contextID: context.id,
                contextName: context.name
            ),
            into: &segments
        )
        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: start.addingTimeInterval(20), state: .active, appBundleID: "com.apple.dt.Xcode", appName: "Xcode"),
                categoryID: CategoryID.work.rawValue,
                contextID: context.id,
                contextName: context.name
            ),
            into: &segments
        )

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].start, start)
        XCTAssertEqual(segments[0].end, start.addingTimeInterval(20))
        XCTAssertEqual(segments[0].duration, 20)
    }

    func testFocusChangeCreatesNewSegmentAndClosesPrevious() {
        let reducer = ActivitySegmentReducer()
        let start = Date(timeIntervalSince1970: 100)
        var segments: [ActivitySegment] = []

        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: start, state: .active, appBundleID: "com.apple.dt.Xcode", appName: "Xcode"),
                categoryID: CategoryID.work.rawValue
            ),
            into: &segments
        )
        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: start.addingTimeInterval(45), state: .active, appBundleID: "com.valvesoftware.steam", appName: "Steam"),
                categoryID: CategoryID.videogames.rawValue
            ),
            into: &segments
        )

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].end, start.addingTimeInterval(45))
        XCTAssertEqual(segments[1].start, start.addingTimeInterval(45))
        XCTAssertEqual(segments[1].categoryID, CategoryID.videogames.rawValue)
    }

    func testIdleStateCreatesInactiveSegmentAfterThreshold() {
        let idleClassifier = IdleClassifier(threshold: 30)
        XCTAssertEqual(idleClassifier.state(forIdleTime: 29.9), .active)
        XCTAssertEqual(idleClassifier.state(forIdleTime: 30), .inactive)

        let reducer = ActivitySegmentReducer()
        let start = Date(timeIntervalSince1970: 100)
        var segments: [ActivitySegment] = []
        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: start, state: .active, appBundleID: "com.apple.finder", appName: "Finder"),
                categoryID: CategoryID.personal.rawValue
            ),
            into: &segments
        )
        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: start.addingTimeInterval(30), state: .inactive, appBundleID: "com.apple.finder", appName: "Finder"),
                categoryID: CategoryID.inactive.rawValue
            ),
            into: &segments
        )

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[1].state, .inactive)
        XCTAssertEqual(segments[1].categoryID, CategoryID.inactive.rawValue)
    }

    func testInactiveBoundaryKeepsWakeActivitySeparate() {
        let reducer = ActivitySegmentReducer()
        let start = Date(timeIntervalSince1970: 100)
        var segments: [ActivitySegment] = []

        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: start, state: .active, appBundleID: "com.apple.dt.Xcode", appName: "Xcode"),
                categoryID: CategoryID.work.rawValue
            ),
            into: &segments
        )
        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: start.addingTimeInterval(10), state: .inactive),
                categoryID: CategoryID.inactive.rawValue
            ),
            into: &segments
        )
        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: start.addingTimeInterval(20), state: .active, appBundleID: "com.apple.dt.Xcode", appName: "Xcode"),
                categoryID: CategoryID.work.rawValue
            ),
            into: &segments
        )

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].state, .active)
        XCTAssertEqual(segments[1].state, .inactive)
        XCTAssertEqual(segments[2].state, .active)
        XCTAssertEqual(segments[0].end, start.addingTimeInterval(10))
        XCTAssertEqual(segments[2].start, start.addingTimeInterval(20))
    }

    func testContextChangeCreatesNewSegment() {
        let reducer = ActivitySegmentReducer()
        let start = Date(timeIntervalSince1970: 100)
        let firstContext = ProjectContext(name: "Client A", defaultCategoryID: CategoryID.work.rawValue)
        let secondContext = ProjectContext(name: "Client B", defaultCategoryID: CategoryID.work.rawValue)
        var segments: [ActivitySegment] = []

        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: start, state: .active, appBundleID: "com.apple.dt.Xcode", appName: "Xcode"),
                categoryID: CategoryID.work.rawValue,
                contextID: firstContext.id,
                contextName: firstContext.name
            ),
            into: &segments
        )
        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: start.addingTimeInterval(15), state: .active, appBundleID: "com.apple.dt.Xcode", appName: "Xcode"),
                categoryID: CategoryID.work.rawValue,
                contextID: secondContext.id,
                contextName: secondContext.name
            ),
            into: &segments
        )

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].contextID, firstContext.id)
        XCTAssertEqual(segments[1].contextID, secondContext.id)
    }

    func testWindowTitleOrURLChangeCreatesNewSegment() {
        let reducer = ActivitySegmentReducer()
        let start = Date(timeIntervalSince1970: 100)
        var segments: [ActivitySegment] = []

        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(
                    timestamp: start,
                    state: .active,
                    appBundleID: "com.google.Chrome",
                    appName: "Chrome",
                    windowTitle: "GitHub",
                    urlString: "https://github.com/nicolopadovan/daily-replica"
                ),
                categoryID: CategoryID.work.rawValue
            ),
            into: &segments
        )
        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(
                    timestamp: start.addingTimeInterval(15),
                    state: .active,
                    appBundleID: "com.google.Chrome",
                    appName: "Chrome",
                    windowTitle: "Docs",
                    urlString: "https://github.com/nicolopadovan/daily-replica"
                ),
                categoryID: CategoryID.work.rawValue
            ),
            into: &segments
        )
        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(
                    timestamp: start.addingTimeInterval(30),
                    state: .active,
                    appBundleID: "com.google.Chrome",
                    appName: "Chrome",
                    windowTitle: "Docs",
                    urlString: "https://developer.apple.com/documentation/appkit/nsworkspace"
                ),
                categoryID: CategoryID.work.rawValue
            ),
            into: &segments
        )

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].windowTitle, "GitHub")
        XCTAssertEqual(segments[1].windowTitle, "Docs")
        XCTAssertEqual(segments[2].urlHost, "developer.apple.com")
    }

    func testManualSegmentEditDoesNotChangeFutureSegmentClassification() {
        let reducer = ActivitySegmentReducer()
        let start = Date(timeIntervalSince1970: 100)
        var segments: [ActivitySegment] = []
        let sample = ClassifiedSample(
            focus: FocusSample(timestamp: start, state: .active, appBundleID: "com.apple.dt.Xcode", appName: "Xcode"),
            categoryID: CategoryID.work.rawValue
        )
        reducer.ingest(sample, into: &segments)
        reducer.editSegment(id: segments[0].id, in: &segments, categoryID: CategoryID.personal.rawValue, editedAt: start.addingTimeInterval(5))
        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: start.addingTimeInterval(10), state: .active, appBundleID: "com.apple.dt.Xcode", appName: "Xcode"),
                categoryID: CategoryID.work.rawValue
            ),
            into: &segments
        )

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].manualCategoryID, CategoryID.personal.rawValue)
        XCTAssertEqual(segments[0].categoryID, CategoryID.personal.rawValue)
        XCTAssertEqual(segments[1].categoryID, CategoryID.work.rawValue)
        XCTAssertNil(segments[1].manualCategoryID)
    }
}
