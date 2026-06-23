import Foundation

public enum SmartPromptKind: String, Codable, Equatable, Sendable {
    case categoryMismatch
    case unclassifiedActivity
}

public struct SmartPrompt: Equatable, Identifiable, Sendable {
    public var id: String { key }
    public var kind: SmartPromptKind
    public var key: String
    public var title: String
    public var message: String
    public var appBundleID: String?
    public var appName: String?
    public var urlHost: String?
    public var currentCategoryID: String
    public var suggestedCategoryID: String?

    public init(
        kind: SmartPromptKind,
        key: String,
        title: String,
        message: String,
        appBundleID: String? = nil,
        appName: String? = nil,
        urlHost: String? = nil,
        currentCategoryID: String,
        suggestedCategoryID: String? = nil
    ) {
        self.kind = kind
        self.key = key
        self.title = title
        self.message = message
        self.appBundleID = appBundleID
        self.appName = appName
        self.urlHost = urlHost
        self.currentCategoryID = currentCategoryID
        self.suggestedCategoryID = suggestedCategoryID
    }
}

public struct SmartPromptEngine: Sendable {
    public var mismatchThreshold: TimeInterval
    public var unclassifiedThreshold: TimeInterval
    public var cooldown: TimeInterval
    private var lastPromptedAtByKey: [String: Date]

    public init(
        mismatchThreshold: TimeInterval = 5 * 60,
        unclassifiedThreshold: TimeInterval = 2 * 60,
        cooldown: TimeInterval = 30 * 60,
        lastPromptedAtByKey: [String: Date] = [:]
    ) {
        self.mismatchThreshold = mismatchThreshold
        self.unclassifiedThreshold = unclassifiedThreshold
        self.cooldown = cooldown
        self.lastPromptedAtByKey = lastPromptedAtByKey
    }

    public mutating func evaluate(
        segment: ActivitySegment,
        currentContext: ProjectContext?,
        now: Date
    ) -> SmartPrompt? {
        guard segment.state == .active else {
            return nil
        }

        if segment.categoryID == CategoryID.unclassified.rawValue,
           now.timeIntervalSince(segment.start) >= unclassifiedThreshold {
            let identity = segment.urlHost ?? segment.appBundleID ?? segment.appName ?? "unknown"
            let key = "unclassified:\(identity)"
            guard canPrompt(key: key, now: now) else {
                return nil
            }
            return SmartPrompt(
                kind: .unclassifiedActivity,
                key: key,
                title: "Classify \(segment.appName ?? "this app")?",
                message: "Daily Replica has seen this activity for at least \(Self.minutes(unclassifiedThreshold)) minutes without a category.",
                appBundleID: segment.appBundleID,
                appName: segment.appName,
                urlHost: segment.urlHost,
                currentCategoryID: segment.categoryID
            )
        }

        if let currentContext,
           let expectedCategory = currentContext.defaultCategoryID,
           expectedCategory != segment.categoryID,
           segment.categoryID != CategoryID.inactive.rawValue,
           segment.categoryID != CategoryID.unclassified.rawValue,
           now.timeIntervalSince(segment.start) >= mismatchThreshold {
            let identity = segment.urlHost ?? segment.appBundleID ?? segment.appName ?? "unknown"
            let key = "mismatch:\(currentContext.id.uuidString):\(segment.categoryID):\(identity)"
            guard canPrompt(key: key, now: now) else {
                return nil
            }
            return SmartPrompt(
                kind: .categoryMismatch,
                key: key,
                title: "Still working on \(currentContext.name)?",
                message: "\(segment.appName ?? "The current app") is categorized as \(segment.categoryID), while the current context defaults to \(expectedCategory).",
                appBundleID: segment.appBundleID,
                appName: segment.appName,
                urlHost: segment.urlHost,
                currentCategoryID: segment.categoryID,
                suggestedCategoryID: expectedCategory
            )
        }

        return nil
    }

    public mutating func recordPrompt(_ prompt: SmartPrompt, at date: Date) {
        lastPromptedAtByKey[prompt.key] = date
    }

    public func lastPromptedAt(for key: String) -> Date? {
        lastPromptedAtByKey[key]
    }

    private func canPrompt(key: String, now: Date) -> Bool {
        guard let last = lastPromptedAtByKey[key] else {
            return true
        }
        return now.timeIntervalSince(last) >= cooldown
    }

    private static func minutes(_ interval: TimeInterval) -> Int {
        max(1, Int(interval / 60))
    }
}
