import XCTest
@testable import DailyReplicaCore

final class ActivityClassifierTests: XCTestCase {
    func testInactiveOverridesRules() {
        let classifier = ActivityClassifier()
        let sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 10),
            state: .inactive,
            appBundleID: "com.google.Chrome",
            urlString: "https://github.com/org/repo"
        )
        let rules = [
            ClassificationRule(kind: .chromeHost, pattern: "github.com", categoryID: CategoryID.work.rawValue),
            ClassificationRule(kind: .appBundleID, pattern: "com.google.Chrome", categoryID: CategoryID.browsing.rawValue)
        ]

        let result = classifier.classify(sample, rules: rules)

        XCTAssertEqual(result.categoryID, CategoryID.inactive.rawValue)
        XCTAssertNil(result.matchedRule)
    }

    func testChromeHostRuleBeatsAppRule() {
        let classifier = ActivityClassifier()
        let sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 10),
            state: .active,
            appBundleID: "com.google.Chrome",
            appName: "Google Chrome",
            urlString: "https://github.com/org/repo"
        )
        let rules = [
            ClassificationRule(kind: .appBundleID, pattern: "com.google.Chrome", categoryID: CategoryID.browsing.rawValue),
            ClassificationRule(kind: .chromeHost, pattern: "github.com", categoryID: CategoryID.work.rawValue)
        ]

        let result = classifier.classify(sample, rules: rules)

        XCTAssertEqual(result.categoryID, CategoryID.work.rawValue)
        XCTAssertEqual(result.matchedRule?.kind, .chromeHost)
    }

    func testHostRuleMatchesSubdomains() {
        XCTAssertTrue(ActivityClassifier.host("docs.github.com", matches: "github.com"))
        XCTAssertFalse(ActivityClassifier.host("notgithub.com", matches: "github.com"))
    }

    func testUnknownActiveAppIsUnclassified() {
        let classifier = ActivityClassifier()
        let sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 10),
            state: .active,
            appBundleID: "com.example.Unknown"
        )

        let result = classifier.classify(sample, rules: [])

        XCTAssertEqual(result.categoryID, CategoryID.unclassified.rawValue)
    }
}
