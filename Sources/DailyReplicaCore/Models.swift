import Foundation

public enum ActivityState: String, Codable, Equatable, Sendable {
    case active
    case inactive
}

public enum CategoryID: String, Codable, CaseIterable, Identifiable, Sendable {
    case work
    case videogames
    case communication
    case browsing
    case media
    case personal
    case unclassified
    case inactive

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .work: "Work"
        case .videogames: "Videogames"
        case .communication: "Communication"
        case .browsing: "Browsing"
        case .media: "Media"
        case .personal: "Personal"
        case .unclassified: "Unclassified"
        case .inactive: "Inactive"
        }
    }

    public static let builtInDefinitions: [CategoryDefinition] = allCases.map {
        CategoryDefinition(id: $0.rawValue, name: $0.displayName, isBuiltIn: true)
    }
}

public struct CategoryDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var isBuiltIn: Bool

    public init(id: String, name: String, isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
    }
}

public struct ProjectContext: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var defaultCategoryID: String?
    public var isArchived: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        defaultCategoryID: String? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.defaultCategoryID = defaultCategoryID
        self.isArchived = isArchived
        self.createdAt = createdAt
    }
}

public struct ProjectSession: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var contextID: UUID
    public var contextName: String
    public var start: Date
    public var end: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        contextID: UUID,
        contextName: String,
        start: Date,
        end: Date? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.contextID = contextID
        self.contextName = contextName
        self.start = start
        self.end = end
        self.createdAt = createdAt ?? start
        self.updatedAt = updatedAt ?? end ?? start
    }

    public func duration(until now: Date = Date()) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }
}

public enum ClassificationRuleKind: String, Codable, CaseIterable, Sendable {
    case appBundleID
    case appName
    case chromeHost
}

public struct ClassificationRule: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: ClassificationRuleKind
    public var pattern: String
    public var categoryID: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: ClassificationRuleKind,
        pattern: String,
        categoryID: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.pattern = Self.normalizedPattern(pattern, kind: kind)
        self.categoryID = categoryID
        self.createdAt = createdAt
    }

    public static func normalizedPattern(_ pattern: String, kind: ClassificationRuleKind) -> String {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .appBundleID, .appName:
            return trimmed
        case .chromeHost:
            return trimmed.lowercased()
        }
    }
}

public struct FocusSample: Equatable, Sendable {
    public var timestamp: Date
    public var state: ActivityState
    public var appBundleID: String?
    public var appName: String?
    public var windowTitle: String?
    public var urlString: String?

    public init(
        timestamp: Date,
        state: ActivityState,
        appBundleID: String? = nil,
        appName: String? = nil,
        windowTitle: String? = nil,
        urlString: String? = nil
    ) {
        self.timestamp = timestamp
        self.state = state
        self.appBundleID = appBundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.urlString = urlString
    }

    public var urlHost: String? {
        guard let urlString, let host = URL(string: urlString)?.host else {
            return nil
        }
        return host.lowercased()
    }
}

public struct ClassifiedSample: Equatable, Sendable {
    public var focus: FocusSample
    public var categoryID: String
    public var contextID: UUID?
    public var contextName: String?

    public init(
        focus: FocusSample,
        categoryID: String,
        contextID: UUID? = nil,
        contextName: String? = nil
    ) {
        self.focus = focus
        self.categoryID = categoryID
        self.contextID = contextID
        self.contextName = contextName
    }
}

public struct ActivitySegment: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var start: Date
    public var end: Date
    public var state: ActivityState
    public var appBundleID: String?
    public var appName: String?
    public var windowTitle: String?
    public var urlString: String?
    public var urlHost: String?
    public var categoryID: String
    public var contextID: UUID?
    public var contextName: String?
    public var manualCategoryID: String?
    public var manualContextID: UUID?
    public var manualNote: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        start: Date,
        end: Date,
        state: ActivityState,
        appBundleID: String? = nil,
        appName: String? = nil,
        windowTitle: String? = nil,
        urlString: String? = nil,
        urlHost: String? = nil,
        categoryID: String,
        contextID: UUID? = nil,
        contextName: String? = nil,
        manualCategoryID: String? = nil,
        manualContextID: UUID? = nil,
        manualNote: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.state = state
        self.appBundleID = appBundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.urlString = urlString
        self.urlHost = urlHost
        self.categoryID = categoryID
        self.contextID = contextID
        self.contextName = contextName
        self.manualCategoryID = manualCategoryID
        self.manualContextID = manualContextID
        self.manualNote = manualNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var duration: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }

    public var hasManualOverride: Bool {
        manualCategoryID != nil || manualContextID != nil || manualNote != nil
    }

    public func matchesContinuation(_ sample: ClassifiedSample) -> Bool {
        guard !hasManualOverride else {
            return false
        }
        return state == sample.focus.state
            && appBundleID == sample.focus.appBundleID
            && appName == sample.focus.appName
            && windowTitle == sample.focus.windowTitle
            && urlString == sample.focus.urlString
            && urlHost == sample.focus.urlHost
            && categoryID == sample.categoryID
            && contextID == sample.contextID
            && contextName == sample.contextName
    }

    public func applyingManualEdit(
        categoryID newCategoryID: String? = nil,
        context: ProjectContext? = nil,
        note: String? = nil,
        editedAt: Date = Date()
    ) -> ActivitySegment {
        var edited = self
        if let newCategoryID {
            edited.categoryID = newCategoryID
            edited.manualCategoryID = newCategoryID
        }
        if let context {
            edited.contextID = context.id
            edited.contextName = context.name
            edited.manualContextID = context.id
        }
        if let note {
            edited.manualNote = note
        }
        edited.updatedAt = editedAt
        return edited
    }
}
