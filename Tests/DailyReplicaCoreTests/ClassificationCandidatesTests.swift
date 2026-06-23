import XCTest
@testable import DailyReplicaCore

final class ClassificationCandidatesTests: XCTestCase {
    func testRepeatedManualAppCorrectionsProduceRuleSuggestion() {
        let segments = [
            correctedAppSegment(appBundleID: "com.example.Editor", appName: "Editor", start: 0, end: 120),
            correctedAppSegment(appBundleID: "com.example.Editor", appName: "Editor", start: 120, end: 300)
        ]

        let suggestions = ClassificationCandidatePresenter.ruleSuggestions(from: segments, rules: [])

        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.kind, .appBundleID)
        XCTAssertEqual(suggestions.first?.pattern, "com.example.Editor")
        XCTAssertEqual(suggestions.first?.suggestedCategoryID, CategoryID.work.rawValue)
        XCTAssertEqual(suggestions.first?.segmentCount, 2)
        XCTAssertEqual(suggestions.first?.duration, 300)
    }

    func testRepeatedManualHostCorrectionsPreferHostSuggestion() {
        let segments = [
            correctedHostSegment(urlHost: "github.com", urlString: nil, start: 0, end: 90),
            correctedHostSegment(urlHost: nil, urlString: "https://github.com/nicolopadovan/daily-replica", start: 90, end: 180)
        ]

        let suggestions = ClassificationCandidatePresenter.ruleSuggestions(from: segments, rules: [])

        XCTAssertEqual(suggestions.map(\.kind), [.chromeHost])
        XCTAssertEqual(suggestions.first?.pattern, "github.com")
        XCTAssertEqual(suggestions.first?.title, "github.com")
    }

    func testExistingRulesSuppressSuggestionsAndUnclassifiedCandidates() {
        let rules = [
            ClassificationRule(kind: .appBundleID, pattern: "com.example.Editor", categoryID: CategoryID.work.rawValue),
            ClassificationRule(kind: .chromeHost, pattern: "github.com", categoryID: CategoryID.work.rawValue)
        ]
        let corrected = [
            correctedAppSegment(appBundleID: "com.example.Editor", appName: "Editor", start: 0, end: 120),
            correctedAppSegment(appBundleID: "com.example.Editor", appName: "Editor", start: 120, end: 240)
        ]
        let unclassified = [
            unclassifiedHostSegment(urlHost: "github.com", start: 240, end: 360)
        ]

        XCTAssertTrue(ClassificationCandidatePresenter.ruleSuggestions(from: corrected, rules: rules).isEmpty)
        XCTAssertTrue(ClassificationCandidatePresenter.unclassifiedCandidates(from: unclassified, rules: rules).isEmpty)
    }

    func testUnclassifiedCandidatesSortByDurationThenTitle() {
        let segments = [
            unclassifiedAppSegment(appBundleID: "com.example.Short", appName: "Short", start: 0, end: 60),
            unclassifiedAppSegment(appBundleID: "com.example.Beta", appName: "Beta", start: 60, end: 180),
            unclassifiedAppSegment(appBundleID: "com.example.Alpha", appName: "Alpha", start: 180, end: 300)
        ]

        let candidates = ClassificationCandidatePresenter.unclassifiedCandidates(from: segments, rules: [])

        XCTAssertEqual(candidates.map(\.title), ["Alpha", "Beta", "Short"])
        XCTAssertEqual(candidates.map(\.duration), [120, 120, 60])
    }

    func testUnclassifiedBundlelessAppUsesAppNameCandidate() {
        let candidates = ClassificationCandidatePresenter.unclassifiedCandidates(
            from: [
                unclassifiedAppSegment(appBundleID: nil, appName: "java", start: 0, end: 2)
            ],
            rules: []
        )

        XCTAssertEqual(candidates.first?.kind, .appName)
        XCTAssertEqual(candidates.first?.pattern, "java")
        XCTAssertEqual(candidates.first?.title, "java")
    }

    private func correctedAppSegment(
        appBundleID: String,
        appName: String,
        start: TimeInterval,
        end: TimeInterval
    ) -> ActivitySegment {
        ActivitySegment(
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: end),
            state: .active,
            appBundleID: appBundleID,
            appName: appName,
            categoryID: CategoryID.work.rawValue,
            manualCategoryID: CategoryID.work.rawValue
        )
    }

    private func correctedHostSegment(
        urlHost: String?,
        urlString: String?,
        start: TimeInterval,
        end: TimeInterval
    ) -> ActivitySegment {
        ActivitySegment(
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: end),
            state: .active,
            appBundleID: "com.google.Chrome",
            appName: "Google Chrome",
            urlString: urlString,
            urlHost: urlHost,
            categoryID: CategoryID.work.rawValue,
            manualCategoryID: CategoryID.work.rawValue
        )
    }

    private func unclassifiedAppSegment(
        appBundleID: String?,
        appName: String,
        start: TimeInterval,
        end: TimeInterval
    ) -> ActivitySegment {
        ActivitySegment(
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: end),
            state: .active,
            appBundleID: appBundleID,
            appName: appName,
            categoryID: CategoryID.unclassified.rawValue
        )
    }

    private func unclassifiedHostSegment(urlHost: String, start: TimeInterval, end: TimeInterval) -> ActivitySegment {
        ActivitySegment(
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: end),
            state: .active,
            appBundleID: "com.google.Chrome",
            appName: "Google Chrome",
            urlHost: urlHost,
            categoryID: CategoryID.unclassified.rawValue
        )
    }
}
