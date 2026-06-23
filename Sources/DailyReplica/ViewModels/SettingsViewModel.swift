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

    private let state: AppState
    private let libraryService: LibraryService
    private var stateCancellable: AnyCancellable?

    init(state: AppState, libraryService: LibraryService) {
        self.state = state
        self.libraryService = libraryService
        stateCancellable = state.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var categories: [CategoryDefinition] { state.categories }
    var contexts: [ProjectContext] { state.contexts }
    var rules: [ClassificationRule] { state.rules }
    var accessibilityTrusted: Bool { state.accessibilityTrusted }

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
        libraryService.addRule(kind: ruleKind, pattern: rulePattern, categoryID: ruleCategoryID)
        rulePattern = ""
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
