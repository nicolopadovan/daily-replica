import Foundation
import SQLite3

public enum SQLiteActivityStoreError: Error, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case executeFailed(String)
    case stepFailed(String)

    public var errorDescription: String? {
        switch self {
        case .openFailed(let message): "Could not open activity store: \(message)"
        case .prepareFailed(let message): "Could not prepare SQLite statement: \(message)"
        case .executeFailed(let message): "Could not execute SQLite statement: \(message)"
        case .stepFailed(let message): "Could not step SQLite statement: \(message)"
        }
    }
}

public final class SQLiteActivityStore {
    private var db: OpaquePointer?

    public init(path: String) throws {
        if path != ":memory:" {
            let directory = URL(fileURLWithPath: path).deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        guard sqlite3_open(path, &db) == SQLITE_OK else {
            throw SQLiteActivityStoreError.openFailed(Self.message(db))
        }

        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    public func fetchCategories() throws -> [CategoryDefinition] {
        let statement = try prepare(
            "SELECT id, name, is_built_in FROM categories ORDER BY is_built_in DESC, name ASC"
        )
        defer { sqlite3_finalize(statement) }

        var categories: [CategoryDefinition] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            categories.append(
                CategoryDefinition(
                    id: columnText(statement, 0) ?? "",
                    name: columnText(statement, 1) ?? "",
                    isBuiltIn: sqlite3_column_int(statement, 2) == 1
                )
            )
        }
        return categories
    }

    public func upsertCategory(_ category: CategoryDefinition) throws {
        let statement = try prepare(
            """
            INSERT INTO categories (id, name, is_built_in)
            VALUES (?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                is_built_in = excluded.is_built_in
            """
        )
        defer { sqlite3_finalize(statement) }
        bindText(statement, 1, category.id)
        bindText(statement, 2, category.name)
        sqlite3_bind_int(statement, 3, category.isBuiltIn ? 1 : 0)
        try stepDone(statement)
    }

    public func fetchContexts(includeArchived: Bool = false) throws -> [ProjectContext] {
        let statement = try prepare(
            """
            SELECT id, name, default_category_id, is_archived, created_at
            FROM project_contexts
            WHERE ? = 1 OR is_archived = 0
            ORDER BY is_archived ASC, name ASC
            """
        )
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int(statement, 1, includeArchived ? 1 : 0)

        var contexts: [ProjectContext] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let idString = columnText(statement, 0), let id = UUID(uuidString: idString) else {
                continue
            }
            contexts.append(
                ProjectContext(
                    id: id,
                    name: columnText(statement, 1) ?? "",
                    defaultCategoryID: columnText(statement, 2),
                    isArchived: sqlite3_column_int(statement, 3) == 1,
                    createdAt: columnDate(statement, 4) ?? Date()
                )
            )
        }
        return contexts
    }

    public func upsertContext(_ context: ProjectContext) throws {
        let statement = try prepare(
            """
            INSERT INTO project_contexts (id, name, default_category_id, is_archived, created_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                name = excluded.name,
                default_category_id = excluded.default_category_id,
                is_archived = excluded.is_archived
            """
        )
        defer { sqlite3_finalize(statement) }
        bindUUID(statement, 1, context.id)
        bindText(statement, 2, context.name)
        bindText(statement, 3, context.defaultCategoryID)
        sqlite3_bind_int(statement, 4, context.isArchived ? 1 : 0)
        bindDate(statement, 5, context.createdAt)
        try stepDone(statement)
    }

    public func fetchRules() throws -> [ClassificationRule] {
        let statement = try prepare(
            """
            SELECT id, kind, pattern, category_id, created_at
            FROM classification_rules
            ORDER BY kind ASC, pattern ASC
            """
        )
        defer { sqlite3_finalize(statement) }

        var rules: [ClassificationRule] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idString = columnText(statement, 0),
                let id = UUID(uuidString: idString),
                let kindString = columnText(statement, 1),
                let kind = ClassificationRuleKind(rawValue: kindString)
            else {
                continue
            }
            rules.append(
                ClassificationRule(
                    id: id,
                    kind: kind,
                    pattern: columnText(statement, 2) ?? "",
                    categoryID: columnText(statement, 3) ?? CategoryID.unclassified.rawValue,
                    createdAt: columnDate(statement, 4) ?? Date()
                )
            )
        }
        return rules
    }

    public func upsertRule(_ rule: ClassificationRule) throws {
        let statement = try prepare(
            """
            INSERT INTO classification_rules (id, kind, pattern, category_id, created_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                kind = excluded.kind,
                pattern = excluded.pattern,
                category_id = excluded.category_id
            """
        )
        defer { sqlite3_finalize(statement) }
        bindUUID(statement, 1, rule.id)
        bindText(statement, 2, rule.kind.rawValue)
        bindText(statement, 3, rule.pattern)
        bindText(statement, 4, rule.categoryID)
        bindDate(statement, 5, rule.createdAt)
        try stepDone(statement)
    }

    public func deleteRule(id: UUID) throws {
        let statement = try prepare("DELETE FROM classification_rules WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        bindUUID(statement, 1, id)
        try stepDone(statement)
    }

    public func upsertSegment(_ segment: ActivitySegment) throws {
        let statement = try prepare(
            """
            INSERT INTO activity_segments (
                id, start_at, end_at, state, app_bundle_id, app_name, window_title,
                url_string, url_host, category_id, context_id, context_name,
                manual_category_id, manual_context_id, manual_note, created_at, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                start_at = excluded.start_at,
                end_at = excluded.end_at,
                state = excluded.state,
                app_bundle_id = excluded.app_bundle_id,
                app_name = excluded.app_name,
                window_title = excluded.window_title,
                url_string = excluded.url_string,
                url_host = excluded.url_host,
                category_id = excluded.category_id,
                context_id = excluded.context_id,
                context_name = excluded.context_name,
                manual_category_id = excluded.manual_category_id,
                manual_context_id = excluded.manual_context_id,
                manual_note = excluded.manual_note,
                updated_at = excluded.updated_at
            """
        )
        defer { sqlite3_finalize(statement) }
        bindSegment(segment, to: statement)
        try stepDone(statement)
    }

    public func fetchSegments(in interval: DateInterval) throws -> [ActivitySegment] {
        let statement = try prepare(
            """
            SELECT id, start_at, end_at, state, app_bundle_id, app_name, window_title,
                   url_string, url_host, category_id, context_id, context_name,
                   manual_category_id, manual_context_id, manual_note, created_at, updated_at
            FROM activity_segments
            WHERE start_at < ? AND end_at >= ?
            ORDER BY start_at ASC
            """
        )
        defer { sqlite3_finalize(statement) }
        bindDate(statement, 1, interval.end)
        bindDate(statement, 2, interval.start)

        var segments: [ActivitySegment] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let segment = readSegment(statement) {
                segments.append(segment)
            }
        }
        return segments
    }

    private func migrate() throws {
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA foreign_keys = ON")
        try execute(
            """
            CREATE TABLE IF NOT EXISTS categories (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                is_built_in INTEGER NOT NULL DEFAULT 0
            )
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS project_contexts (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                default_category_id TEXT,
                is_archived INTEGER NOT NULL DEFAULT 0,
                created_at REAL NOT NULL
            )
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS classification_rules (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                pattern TEXT NOT NULL,
                category_id TEXT NOT NULL,
                created_at REAL NOT NULL
            )
            """
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS classification_rules_lookup
            ON classification_rules (kind, pattern)
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS activity_segments (
                id TEXT PRIMARY KEY,
                start_at REAL NOT NULL,
                end_at REAL NOT NULL,
                state TEXT NOT NULL,
                app_bundle_id TEXT,
                app_name TEXT,
                window_title TEXT,
                url_string TEXT,
                url_host TEXT,
                category_id TEXT NOT NULL,
                context_id TEXT,
                context_name TEXT,
                manual_category_id TEXT,
                manual_context_id TEXT,
                manual_note TEXT,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL
            )
            """
        )
        try execute(
            """
            CREATE INDEX IF NOT EXISTS activity_segments_time
            ON activity_segments (start_at, end_at)
            """
        )

        for category in CategoryID.builtInDefinitions {
            try upsertCategory(category)
        }
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw SQLiteActivityStoreError.executeFailed(Self.message(db))
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteActivityStoreError.prepareFailed(Self.message(db))
        }
        return statement
    }

    private func stepDone(_ statement: OpaquePointer?) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteActivityStoreError.stepFailed(Self.message(db))
        }
    }

    private func bindSegment(_ segment: ActivitySegment, to statement: OpaquePointer?) {
        bindUUID(statement, 1, segment.id)
        bindDate(statement, 2, segment.start)
        bindDate(statement, 3, segment.end)
        bindText(statement, 4, segment.state.rawValue)
        bindText(statement, 5, segment.appBundleID)
        bindText(statement, 6, segment.appName)
        bindText(statement, 7, segment.windowTitle)
        bindText(statement, 8, segment.urlString)
        bindText(statement, 9, segment.urlHost)
        bindText(statement, 10, segment.categoryID)
        bindUUID(statement, 11, segment.contextID)
        bindText(statement, 12, segment.contextName)
        bindText(statement, 13, segment.manualCategoryID)
        bindUUID(statement, 14, segment.manualContextID)
        bindText(statement, 15, segment.manualNote)
        bindDate(statement, 16, segment.createdAt)
        bindDate(statement, 17, segment.updatedAt)
    }

    private func readSegment(_ statement: OpaquePointer?) -> ActivitySegment? {
        guard
            let idString = columnText(statement, 0),
            let id = UUID(uuidString: idString),
            let start = columnDate(statement, 1),
            let end = columnDate(statement, 2),
            let stateString = columnText(statement, 3),
            let state = ActivityState(rawValue: stateString)
        else {
            return nil
        }

        return ActivitySegment(
            id: id,
            start: start,
            end: end,
            state: state,
            appBundleID: columnText(statement, 4),
            appName: columnText(statement, 5),
            windowTitle: columnText(statement, 6),
            urlString: columnText(statement, 7),
            urlHost: columnText(statement, 8),
            categoryID: columnText(statement, 9) ?? CategoryID.unclassified.rawValue,
            contextID: columnUUID(statement, 10),
            contextName: columnText(statement, 11),
            manualCategoryID: columnText(statement, 12),
            manualContextID: columnUUID(statement, 13),
            manualNote: columnText(statement, 14),
            createdAt: columnDate(statement, 15) ?? start,
            updatedAt: columnDate(statement, 16) ?? end
        )
    }

    private func bindText(_ statement: OpaquePointer?, _ index: Int32, _ value: String?) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }
        sqlite3_bind_text(statement, index, value, -1, Self.transientDestructor)
    }

    private func bindUUID(_ statement: OpaquePointer?, _ index: Int32, _ value: UUID?) {
        bindText(statement, index, value?.uuidString)
    }

    private func bindDate(_ statement: OpaquePointer?, _ index: Int32, _ value: Date) {
        sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
    }

    private func columnText(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let pointer = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: pointer)
    }

    private func columnUUID(_ statement: OpaquePointer?, _ index: Int32) -> UUID? {
        guard let text = columnText(statement, index) else {
            return nil
        }
        return UUID(uuidString: text)
    }

    private func columnDate(_ statement: OpaquePointer?, _ index: Int32) -> Date? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }

    private static var transientDestructor: sqlite3_destructor_type {
        unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    }

    private static func message(_ db: OpaquePointer?) -> String {
        guard let message = sqlite3_errmsg(db) else {
            return "Unknown SQLite error"
        }
        return String(cString: message)
    }
}
