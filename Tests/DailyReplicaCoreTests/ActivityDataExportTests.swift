import XCTest
@testable import DailyReplicaCore

final class ActivityDataExportTests: XCTestCase {
    func testJSONExportEncodesWholeSnapshot() throws {
        let context = ProjectContext(name: "Daily Replica", defaultCategoryID: CategoryID.work.rawValue)
        let snapshot = ActivityExportSnapshot(
            exportedAt: Date(timeIntervalSince1970: 1_000),
            categories: [CategoryDefinition(id: "work", name: "Work", isBuiltIn: true)],
            contexts: [context],
            rules: [ClassificationRule(kind: .appBundleID, pattern: "com.apple.dt.Xcode", categoryID: CategoryID.work.rawValue)],
            segments: [
                ActivitySegment(
                    start: Date(timeIntervalSince1970: 10),
                    end: Date(timeIntervalSince1970: 20),
                    state: .active,
                    appBundleID: "com.apple.dt.Xcode",
                    appName: "Xcode",
                    categoryID: CategoryID.work.rawValue,
                    contextID: context.id,
                    contextName: context.name
                )
            ],
            projectSessions: [
                ProjectSession(
                    contextID: context.id,
                    contextName: context.name,
                    start: Date(timeIntervalSince1970: 10),
                    end: Date(timeIntervalSince1970: 20)
                )
            ]
        )

        let data = try ActivityDataExporter.jsonData(snapshot: snapshot)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(json.contains("\"categories\""))
        XCTAssertTrue(json.contains("\"contexts\""))
        XCTAssertTrue(json.contains("\"rules\""))
        XCTAssertTrue(json.contains("\"segments\""))
        XCTAssertTrue(json.contains("\"projectSessions\""))
        XCTAssertTrue(json.contains("Daily Replica"))
    }

    func testSegmentsCSVIncludesHeaderAndEscapesQuotes() {
        let segments = [
            ActivitySegment(
                start: Date(timeIntervalSince1970: 10),
                end: Date(timeIntervalSince1970: 20),
                state: .active,
                appBundleID: "com.example.App",
                appName: "Example \"App\"",
                windowTitle: "A, B, and \"C\"",
                urlHost: "example.com",
                categoryID: CategoryID.work.rawValue,
                contextName: "Client"
            )
        ]

        let csv = ActivityDataExporter.segmentsCSV(segments: segments)

        XCTAssertTrue(csv.hasPrefix("id,start,end,state,app_bundle_id"))
        XCTAssertTrue(csv.contains("\"Example \"\"App\"\"\""))
        XCTAssertTrue(csv.contains("\"A, B, and \"\"C\"\"\""))
        XCTAssertTrue(csv.contains("example.com"))
    }
}
