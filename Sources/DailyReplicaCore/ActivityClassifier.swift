import Foundation

public struct ClassificationResult: Equatable, Sendable {
    public var categoryID: String
    public var matchedRule: ClassificationRule?

    public init(categoryID: String, matchedRule: ClassificationRule? = nil) {
        self.categoryID = categoryID
        self.matchedRule = matchedRule
    }
}

public struct ActivityClassifier: Sendable {
    public init() {}

    public func classify(_ sample: FocusSample, rules: [ClassificationRule]) -> ClassificationResult {
        guard sample.state == .active else {
            return ClassificationResult(categoryID: CategoryID.inactive.rawValue)
        }

        if let host = sample.urlHost,
           let rule = rules.first(where: { $0.kind == .chromeHost && Self.host(host, matches: $0.pattern) }) {
            return ClassificationResult(categoryID: rule.categoryID, matchedRule: rule)
        }

        if let bundleID = sample.appBundleID,
           let rule = rules.first(where: { $0.kind == .appBundleID && $0.pattern == bundleID }) {
            return ClassificationResult(categoryID: rule.categoryID, matchedRule: rule)
        }

        return ClassificationResult(categoryID: CategoryID.unclassified.rawValue)
    }

    public static func host(_ host: String, matches pattern: String) -> Bool {
        let host = host.lowercased()
        let pattern = pattern.lowercased()
        return host == pattern || host.hasSuffix(".\(pattern)")
    }
}
