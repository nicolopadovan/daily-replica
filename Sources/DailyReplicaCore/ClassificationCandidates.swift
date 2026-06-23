import Foundation

public struct ClassificationCandidate: Equatable, Identifiable, Sendable {
    public var kind: ClassificationRuleKind
    public var pattern: String
    public var suggestedCategoryID: String?
    public var title: String
    public var subtitle: String
    public var segmentCount: Int
    public var duration: TimeInterval

    public var id: String {
        "\(kind.rawValue):\(pattern):\(suggestedCategoryID ?? "")"
    }

    public init(
        kind: ClassificationRuleKind,
        pattern: String,
        suggestedCategoryID: String?,
        title: String,
        subtitle: String,
        segmentCount: Int,
        duration: TimeInterval
    ) {
        self.kind = kind
        self.pattern = ClassificationRule.normalizedPattern(pattern, kind: kind)
        self.suggestedCategoryID = suggestedCategoryID
        self.title = title
        self.subtitle = subtitle
        self.segmentCount = segmentCount
        self.duration = duration
    }
}

public enum ClassificationCandidatePresenter {
    public static func ruleSuggestions(
        from segments: [ActivitySegment],
        rules: [ClassificationRule],
        minimumCorrections: Int = 2
    ) -> [ClassificationCandidate] {
        groupedCandidates(
            from: segments.filter { $0.manualCategoryID != nil && $0.state == .active },
            rules: rules,
            minimumSegments: minimumCorrections,
            categoryID: { $0.manualCategoryID }
        )
    }

    public static func unclassifiedCandidates(
        from segments: [ActivitySegment],
        rules: [ClassificationRule]
    ) -> [ClassificationCandidate] {
        groupedCandidates(
            from: segments.filter { $0.categoryID == CategoryID.unclassified.rawValue && $0.state == .active },
            rules: rules,
            minimumSegments: 1,
            categoryID: { _ in nil }
        )
    }

    private static func groupedCandidates(
        from segments: [ActivitySegment],
        rules: [ClassificationRule],
        minimumSegments: Int,
        categoryID: (ActivitySegment) -> String?
    ) -> [ClassificationCandidate] {
        var groups: [String: (target: Target, categoryID: String?, count: Int, duration: TimeInterval)] = [:]

        for segment in segments {
            guard let target = target(for: segment),
                  !hasRule(for: target, rules: rules) else {
                continue
            }

            let categoryID = categoryID(segment)
            let key = "\(target.kind.rawValue):\(target.pattern):\(categoryID ?? "")"
            let existing = groups[key]
            groups[key] = (
                target,
                categoryID,
                (existing?.count ?? 0) + 1,
                (existing?.duration ?? 0) + segment.duration
            )
        }

        return groups.values
            .filter { $0.count >= minimumSegments }
            .map {
                ClassificationCandidate(
                    kind: $0.target.kind,
                    pattern: $0.target.pattern,
                    suggestedCategoryID: $0.categoryID,
                    title: $0.target.title,
                    subtitle: $0.target.subtitle,
                    segmentCount: $0.count,
                    duration: $0.duration
                )
            }
            .sorted {
                if $0.duration == $1.duration {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.duration > $1.duration
            }
    }

    private static func target(for segment: ActivitySegment) -> Target? {
        if let host = segment.urlHost ?? segment.urlString.flatMap({ URL(string: $0)?.host?.lowercased() }) {
            return Target(kind: .chromeHost, pattern: host, title: host, subtitle: "Chrome website")
        }
        if let bundleID = segment.appBundleID {
            return Target(
                kind: .appBundleID,
                pattern: bundleID,
                title: segment.appName ?? bundleID,
                subtitle: bundleID
            )
        }
        if let appName = segment.appName {
            return Target(kind: .appName, pattern: appName, title: appName, subtitle: "App name")
        }
        return nil
    }

    private static func hasRule(for target: Target, rules: [ClassificationRule]) -> Bool {
        rules.contains {
            switch target.kind {
            case .appBundleID:
                return $0.kind == .appBundleID && $0.pattern == target.pattern
            case .appName:
                return $0.kind == .appName && $0.pattern == target.pattern
            case .chromeHost:
                return $0.kind == .chromeHost && ActivityClassifier.host(target.pattern, matches: $0.pattern)
            }
        }
    }

    private struct Target {
        var kind: ClassificationRuleKind
        var pattern: String
        var title: String
        var subtitle: String
    }
}
