import Foundation

public struct ActivityExportSnapshot: Codable, Equatable, Sendable {
    public var exportedAt: Date
    public var categories: [CategoryDefinition]
    public var contexts: [ProjectContext]
    public var rules: [ClassificationRule]
    public var segments: [ActivitySegment]
    public var projectSessions: [ProjectSession]

    public init(
        exportedAt: Date = Date(),
        categories: [CategoryDefinition],
        contexts: [ProjectContext],
        rules: [ClassificationRule],
        segments: [ActivitySegment],
        projectSessions: [ProjectSession]
    ) {
        self.exportedAt = exportedAt
        self.categories = categories
        self.contexts = contexts
        self.rules = rules
        self.segments = segments
        self.projectSessions = projectSessions
    }
}

public enum ActivityDataExporter {
    public static func jsonData(snapshot: ActivityExportSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(snapshot)
    }

    public static func segmentsCSV(segments: [ActivitySegment]) -> String {
        let header = [
            "id", "start", "end", "state", "app_bundle_id", "app_name", "window_title",
            "url_string", "url_host", "category_id", "context_id", "context_name",
            "manual_category_id", "manual_context_id", "manual_note"
        ]
        let rows = segments.map { segment in
            [
                segment.id.uuidString,
                formattedDate(segment.start),
                formattedDate(segment.end),
                segment.state.rawValue,
                segment.appBundleID,
                segment.appName,
                segment.windowTitle,
                segment.urlString,
                segment.urlHost,
                segment.categoryID,
                segment.contextID?.uuidString,
                segment.contextName,
                segment.manualCategoryID,
                segment.manualContextID?.uuidString,
                segment.manualNote
            ]
            .map(csvField)
            .joined(separator: ",")
        }
        return ([header.joined(separator: ",")] + rows).joined(separator: "\n") + "\n"
    }

    private static func formattedDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func csvField(_ value: String?) -> String {
        let value = value ?? ""
        guard value.contains(",") || value.contains("\"") || value.contains("\n") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
