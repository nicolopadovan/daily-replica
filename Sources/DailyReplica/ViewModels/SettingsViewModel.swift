import Combine
import DailyReplicaCore
import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case categories
    case contexts
    case rules
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .categories: "Categories"
        case .contexts: "Projects"
        case .rules: "Auto-sort"
        case .permissions: "Permissions"
        }
    }

    var systemImage: String {
        switch self {
        case .categories: "square.grid.2x2.fill"
        case .contexts: "folder.fill"
        case .rules: "tag.fill"
        case .permissions: "lock.shield.fill"
        }
    }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var selectedSection = SettingsSection.categories
    @Published var categoryName = ""
    @Published var contextName = ""
    @Published var contextCategoryID = CategoryID.work.rawValue
    @Published var ruleKind = ClassificationRuleKind.appBundleID
    @Published var rulePattern = ""
    @Published var ruleCategoryID = CategoryID.work.rawValue
    @Published var bulkRuleCategoryID = CategoryID.work.rawValue

    private let state: AppState
    private let libraryService: LibraryService
    private let privacyService: PrivacyService
    private var stateCancellable: AnyCancellable?

    init(state: AppState, libraryService: LibraryService, privacyService: PrivacyService) {
        self.state = state
        self.libraryService = libraryService
        self.privacyService = privacyService
        stateCancellable = state.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var categories: [CategoryDefinition] { state.categories }
    var contexts: [ProjectContext] { state.contexts }
    var rules: [ClassificationRule] { state.rules }
    var accessibilityTrusted: Bool { state.accessibilityTrusted }
    var ruleSuggestions: [ClassificationCandidate] {
        ClassificationCandidatePresenter.ruleSuggestions(from: state.todaySegments, rules: state.rules)
    }
    var unclassifiedCandidates: [ClassificationCandidate] {
        ClassificationCandidatePresenter.unclassifiedCandidates(from: state.todaySegments, rules: state.rules)
    }

    var assignableCategories: [CategoryDefinition] {
        state.categories.filter { $0.id != CategoryID.inactive.rawValue }
    }

    func displayName(for categoryID: String) -> String {
        state.displayName(for: categoryID)
    }

    func createCategory() {
        guard libraryService.addCategory(name: categoryName) != nil else {
            return
        }
        categoryName = ""
    }

    func createContext() {
        guard libraryService.addContext(name: contextName, defaultCategoryID: contextCategoryID) != nil else {
            return
        }
        contextName = ""
    }

    func createRule() {
        guard libraryService.addRule(kind: ruleKind, pattern: rulePattern, categoryID: ruleCategoryID) != nil else {
            return
        }
        rulePattern = ""
    }

    func acceptRuleSuggestion(_ suggestion: ClassificationCandidate) {
        guard let categoryID = suggestion.suggestedCategoryID else {
            return
        }
        libraryService.addRule(kind: suggestion.kind, pattern: suggestion.pattern, categoryID: categoryID)
    }

    @discardableResult
    func classifyUncategorized(_ candidate: ClassificationCandidate) -> Int {
        libraryService.classifyUncategorized(
            kind: candidate.kind,
            pattern: candidate.pattern,
            categoryID: bulkRuleCategoryID
        )
    }

    func updateRuleCategory(id: UUID, categoryID: String) {
        libraryService.updateRuleCategory(id: id, categoryID: categoryID)
    }

    func exportJSONText() -> String? {
        do {
            return String(decoding: try privacyService.exportJSONData(), as: UTF8.self)
        } catch {
            state.lastError = error.localizedDescription
            return nil
        }
    }

    func exportSegmentsCSVText() -> String? {
        do {
            return String(decoding: try privacyService.exportSegmentsCSVData(), as: UTF8.self)
        } catch {
            state.lastError = error.localizedDescription
            return nil
        }
    }

    func clearActivityData() {
        privacyService.clearActivityData()
    }

    func resetAllData() {
        privacyService.resetAllData()
    }

    func setCurrentContext(id: UUID) {
        libraryService.setCurrentContext(id: id)
    }

    func archiveContext(id: UUID) {
        libraryService.archiveContext(id: id)
    }

    func deleteRule(id: UUID) {
        libraryService.deleteRule(id: id)
    }

    func requestAccessibilityPermission() {
        libraryService.refreshAccessibilityTrust(prompt: true)
    }
}
