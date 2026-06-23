import DailyReplicaCore
import Foundation

struct AutoSortRuleRequest: Identifiable, Equatable {
    let id = UUID()
    let kind: ClassificationRuleKind
    let pattern: String
    var categoryID: String
    var isEnabled: Bool = true
    let title: String
}

struct AutoSortRuleBatch: Identifiable, Equatable {
    let id = UUID()
    let requests: [AutoSortRuleRequest]
}

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
    func addRule(kind: ClassificationRuleKind, pattern: String, categoryID: String, retroactive: Bool = false) -> ClassificationRule? {
        let normalized = ClassificationRule.normalizedPattern(pattern, kind: kind)
        guard !normalized.isEmpty else {
            return nil
        }
        let rule: ClassificationRule?
        if let index = state.rules.firstIndex(where: { $0.kind == kind && $0.pattern == normalized }) {
            var existingRule = state.rules[index]
            existingRule.categoryID = categoryID
            rule = persistRule(existingRule, replacingIndex: index)
        } else {
            rule = persistRule(ClassificationRule(kind: kind, pattern: normalized, categoryID: categoryID))
        }
        if retroactive, let rule {
            applyRuleRetroactively(rule)
        }
        return rule
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
        let rule = ClassificationRule(kind: kind, pattern: ClassificationRule.normalizedPattern(pattern, kind: kind), categoryID: categoryID)
        let changedCount = matchingUnclassifiedSegmentCount(for: rule)
        guard addRule(kind: kind, pattern: pattern, categoryID: categoryID, retroactive: true) != nil else {
            return 0
        }
        return changedCount
    }

    @discardableResult
    func applyRuleRetroactively(_ rule: ClassificationRule) -> Int {
        do {
            let allSegments = try store.fetchAllSegments()
            var changedCount = 0
            for segment in allSegments where shouldApply(rule, to: segment) {
                let edited = segment.applyingManualEdit(categoryID: rule.categoryID)
                try store.upsertSegment(edited)
                if let index = state.todaySegments.firstIndex(where: { $0.id == edited.id }) {
                    state.todaySegments[index] = edited
                }
                changedCount += 1
            }
            return changedCount
        } catch {
            state.lastError = error.localizedDescription
            return 0
        }
    }

    func existingRule(kind: ClassificationRuleKind, pattern: String) -> ClassificationRule? {
        let normalized = ClassificationRule.normalizedPattern(pattern, kind: kind)
        return state.rules.first { $0.kind == kind && $0.pattern == normalized }
    }

    private func matchingUnclassifiedSegmentCount(for rule: ClassificationRule) -> Int {
        state.todaySegments.filter { shouldApply(rule, to: $0) }.count
    }

    private func shouldApply(_ rule: ClassificationRule, to segment: ActivitySegment) -> Bool {
        segment.state == .active &&
            segment.categoryID == CategoryID.unclassified.rawValue &&
            segmentMatchesRule(segment, rule: rule)
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
        state.accessibilityTrusted = permissionChecker.isAccessibilityTrusted(prompt: prompt) || state.hasObservedWindowTitles
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
        case .appName:
            return segment.appBundleID == nil && segment.appName == rule.pattern
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
