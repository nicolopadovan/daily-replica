import DailyReplicaCore
import Foundation

@MainActor
final class LibraryService {
    private let store: ActivityStore
    private let state: AppState
    private let contextPersistence: CurrentContextPersisting
    private let permissionChecker: PermissionChecking

    init(
        store: ActivityStore,
        state: AppState,
        contextPersistence: CurrentContextPersisting,
        permissionChecker: PermissionChecking
    ) {
        self.store = store
        self.state = state
        self.contextPersistence = contextPersistence
        self.permissionChecker = permissionChecker
    }

    func loadState() {
        do {
            state.categories = try store.fetchCategories()
            state.contexts = try store.fetchContexts()
            if state.contexts.isEmpty {
                let general = ProjectContext(name: "General", defaultCategoryID: CategoryID.work.rawValue)
                try store.upsertContext(general)
                state.contexts = [general]
            }
            state.rules = try store.fetchRules()
            if let id = contextPersistence.loadCurrentContextID(),
               state.contexts.contains(where: { $0.id == id }) {
                state.currentContextID = id
            } else {
                state.currentContextID = state.contexts.first?.id
            }
            reloadToday()
            refreshAccessibilityTrust(prompt: false)
        } catch {
            state.lastError = error.localizedDescription
        }
    }

    func setCurrentContext(id: UUID?) {
        state.currentContextID = id
        contextPersistence.saveCurrentContextID(id)
    }

    @discardableResult
    func addContext(name: String, defaultCategoryID: String?, selectCurrent: Bool = true) -> ProjectContext? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let context = ProjectContext(name: trimmed, defaultCategoryID: defaultCategoryID)
        do {
            try store.upsertContext(context)
            state.contexts.append(context)
            sortContexts()
            if selectCurrent {
                setCurrentContext(id: context.id)
            }
            return context
        } catch {
            state.lastError = error.localizedDescription
            return nil
        }
    }

    @discardableResult
    func addCategory(name: String) -> CategoryDefinition? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let category = CategoryDefinition(id: Self.slug(for: trimmed), name: trimmed)
        if let existing = state.categories.first(where: { $0.id == category.id }) {
            return existing
        }
        do {
            try store.upsertCategory(category)
            state.categories.append(category)
            sortCategories()
            return category
        } catch {
            state.lastError = error.localizedDescription
            return nil
        }
    }

    func archiveContext(id: UUID) {
        guard let index = state.contexts.firstIndex(where: { $0.id == id }) else {
            return
        }
        var context = state.contexts[index]
        context.isArchived = true
        do {
            try store.upsertContext(context)
            state.contexts.remove(at: index)
            if state.currentContextID == id {
                setCurrentContext(id: state.contexts.first?.id)
            }
        } catch {
            state.lastError = error.localizedDescription
        }
    }

    @discardableResult
    func addRule(kind: ClassificationRuleKind, pattern: String, categoryID: String) -> ClassificationRule? {
        let normalized = ClassificationRule.normalizedPattern(pattern, kind: kind)
        guard !normalized.isEmpty else {
            return nil
        }
        if let index = state.rules.firstIndex(where: { $0.kind == kind && $0.pattern == normalized }) {
            var rule = state.rules[index]
            rule.categoryID = categoryID
            return persistRule(rule, replacingIndex: index)
        }
        let rule = ClassificationRule(kind: kind, pattern: normalized, categoryID: categoryID)
        return persistRule(rule)
    }

    func updateRuleCategory(id: UUID, categoryID: String) {
        guard let index = state.rules.firstIndex(where: { $0.id == id }) else {
            return
        }
        var rule = state.rules[index]
        rule.categoryID = categoryID
        _ = persistRule(rule, replacingIndex: index)
    }

    @discardableResult
    func classifyUncategorized(kind: ClassificationRuleKind, pattern: String, categoryID: String) -> Int {
        guard let rule = addRule(kind: kind, pattern: pattern, categoryID: categoryID) else {
            return 0
        }

        var changedCount = 0
        for index in state.todaySegments.indices {
            let segment = state.todaySegments[index]
            guard segment.categoryID == CategoryID.unclassified.rawValue,
                  segmentMatchesRule(segment, rule: rule) else {
                continue
            }

            let edited = segment.applyingManualEdit(categoryID: categoryID)
            do {
                try store.upsertSegment(edited)
                state.todaySegments[index] = edited
                changedCount += 1
            } catch {
                state.lastError = error.localizedDescription
            }
        }
        return changedCount
    }

    private func persistRule(_ rule: ClassificationRule, replacingIndex index: Int? = nil) -> ClassificationRule? {
        do {
            try store.upsertRule(rule)
            if let index {
                state.rules[index] = rule
            } else {
                state.rules.append(rule)
            }
            sortRules()
            return rule
        } catch {
            state.lastError = error.localizedDescription
            return nil
        }
    }

    func deleteRule(id: UUID) {
        do {
            try store.deleteRule(id: id)
            state.rules.removeAll { $0.id == id }
        } catch {
            state.lastError = error.localizedDescription
        }
    }

    func reloadToday() {
        do {
            state.todaySegments = try store.fetchSegments(in: DateInterval.day(containing: Date()))
        } catch {
            state.lastError = error.localizedDescription
        }
    }

    func refreshAccessibilityTrust(prompt: Bool) {
        state.accessibilityTrusted = permissionChecker.isAccessibilityTrusted(prompt: prompt)
    }

    private func sortCategories() {
        state.categories.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func sortContexts() {
        state.contexts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func sortRules() {
        state.rules.sort { $0.pattern.localizedCaseInsensitiveCompare($1.pattern) == .orderedAscending }
    }

    private func segmentMatchesRule(_ segment: ActivitySegment, rule: ClassificationRule) -> Bool {
        switch rule.kind {
        case .appBundleID:
            return segment.appBundleID == rule.pattern
        case .chromeHost:
            guard let host = segment.urlHost ?? segment.urlString.flatMap({ URL(string: $0)?.host }) else {
                return false
            }
            return ActivityClassifier.host(host, matches: rule.pattern)
        }
    }

    private static func slug(for name: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let parts = name.lowercased().unicodeScalars.split { !allowed.contains($0) }
        let slug = parts.map(String.init).joined(separator: "-")
        return slug.isEmpty ? UUID().uuidString : slug
    }
}
