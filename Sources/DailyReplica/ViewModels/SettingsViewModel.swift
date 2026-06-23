import Combine
import DailyReplicaCore
import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case categories
    case contexts
    case rules
    case permissions
    case updates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .categories: "Categories"
        case .contexts: "Projects"
        case .rules: "Auto-sort"
        case .permissions: "Permissions"
        case .updates: "Updates"
        }
    }

    var systemImage: String {
        switch self {
        case .categories: "square.grid.2x2.fill"
        case .contexts: "folder.fill"
        case .rules: "tag.fill"
        case .permissions: "lock.shield.fill"
        case .updates: "arrow.triangle.2.circlepath"
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
    @Published var pendingAutoSortBatch: AutoSortRuleBatch?
    @Published var pendingAutoSortIsRetroactive = true
    @Published private(set) var browserURLPermissions: [String: Bool?] = [:]

    private let state: AppState
    private let libraryService: LibraryService
    private let privacyService: PrivacyService
    private let updateService: UpdateService?
    private var stateCancellable: AnyCancellable?
    private var updateCancellable: AnyCancellable?

    init(
        state: AppState,
        libraryService: LibraryService,
        privacyService: PrivacyService,
        updateService: UpdateService? = nil
    ) {
        self.state = state
        self.libraryService = libraryService
        self.privacyService = privacyService
        self.updateService = updateService
        stateCancellable = state.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        updateCancellable = updateService?.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var categories: [CategoryDefinition] { state.categories }
    var contexts: [ProjectContext] { state.contexts }
    var rules: [ClassificationRule] { state.rules }
    var accessibilityTrusted: Bool { state.accessibilityTrusted }
    var chromeURLsAuthorized: Bool? { state.chromeURLsAuthorized }
    var browserDefinitions: [BrowserURLReader.BrowserDefinition] { BrowserURLReader.supportedBrowsers }
    var updatesConfigured: Bool { updateService?.isConfigured ?? false }
    var canCheckForUpdates: Bool { updateService?.canCheckForUpdates ?? false }
    var automaticallyChecksForUpdates: Bool { updateService?.automaticallyChecksForUpdates ?? false }
    var automaticallyDownloadsUpdates: Bool { updateService?.automaticallyDownloadsUpdates ?? false }
    var allowsAutomaticUpdates: Bool { updateService?.allowsAutomaticUpdates ?? false }
    var updateCheckInterval: TimeInterval { updateService?.updateCheckInterval ?? 86_400 }
    var updateFeedURL: URL? { updateService?.feedURL }
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
        let normalized = ClassificationRule.normalizedPattern(rulePattern, kind: ruleKind)
        guard !normalized.isEmpty else {
            return
        }
        pendingAutoSortBatch = AutoSortRuleBatch(requests: [
            AutoSortRuleRequest(
                kind: ruleKind,
                pattern: normalized,
                categoryID: ruleCategoryID,
                title: normalized
            )
        ])
        pendingAutoSortIsRetroactive = true
    }

    func acceptRuleSuggestion(_ suggestion: ClassificationCandidate) {
        guard let categoryID = suggestion.suggestedCategoryID else {
            return
        }
        pendingAutoSortBatch = AutoSortRuleBatch(requests: [
            AutoSortRuleRequest(
                kind: suggestion.kind,
                pattern: suggestion.pattern,
                categoryID: categoryID,
                title: suggestion.title
            )
        ])
        pendingAutoSortIsRetroactive = true
    }

    @discardableResult
    func classifyUncategorized(_ candidate: ClassificationCandidate) -> Int {
        pendingAutoSortBatch = AutoSortRuleBatch(requests: [
            AutoSortRuleRequest(
                kind: candidate.kind,
                pattern: candidate.pattern,
                categoryID: bulkRuleCategoryID,
                title: candidate.title
            )
        ])
        pendingAutoSortIsRetroactive = true
        return 0
    }

    func confirmPendingAutoSortRule(
        requests: [AutoSortRuleRequest]? = nil,
        retroactive: Bool? = nil
    ) {
        guard let pendingAutoSortBatch else {
            return
        }
        let selectedRequests = requests ?? pendingAutoSortBatch.requests
        let shouldApplyRetroactively = retroactive ?? pendingAutoSortIsRetroactive
        for request in selectedRequests where request.isEnabled {
            libraryService.addRule(
                kind: request.kind,
                pattern: request.pattern,
                categoryID: request.categoryID,
                retroactive: shouldApplyRetroactively
            )
        }
        if let request = pendingAutoSortBatch.requests.first,
           pendingAutoSortBatch.requests.count == 1,
           request.isEnabled,
           ClassificationRule.normalizedPattern(rulePattern, kind: ruleKind) == request.pattern {
            rulePattern = ""
        }
        self.pendingAutoSortBatch = nil
        pendingAutoSortIsRetroactive = true
    }

    func cancelPendingAutoSortRule() {
        pendingAutoSortBatch = nil
        pendingAutoSortIsRetroactive = true
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

    func refreshAccessibilityPermission(prompt: Bool = false) {
        libraryService.refreshAccessibilityTrust(prompt: prompt)
    }

    func requestAccessibilityPermission() {
        refreshAccessibilityPermission(prompt: true)
    }

    func refreshChromeURLPermission() {
        let hasPermission = BrowserURLReader().hasAnyAutomationPermission()
        state.chromeURLsAuthorized = hasPermission
    }

    func refreshBrowserURLPermission(for bundleID: String) -> Bool? {
        guard BrowserURLReader.supports(bundleID: bundleID) else {
            browserURLPermissions[bundleID] = nil
            refreshOverallBrowserPermissionState()
            return nil
        }
        let isAuthorized = BrowserURLReader().hasAutomationPermission(for: bundleID)
        browserURLPermissions[bundleID] = isAuthorized
        refreshOverallBrowserPermissionState()
        return isAuthorized
    }

    func browserURLPermission(for bundleID: String) -> Bool? {
        browserURLPermissions[bundleID] ?? nil
    }

    private func refreshOverallBrowserPermissionState() {
        let knownStatuses = browserURLPermissions.values.compactMap { $0 }
        if knownStatuses.contains(true) {
            state.chromeURLsAuthorized = true
        } else if knownStatuses.contains(false) {
            state.chromeURLsAuthorized = false
        } else {
            state.chromeURLsAuthorized = nil
        }
    }

    func checkForUpdates() {
        updateService?.checkForUpdates()
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updateService?.setAutomaticallyChecksForUpdates(enabled)
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        updateService?.setAutomaticallyDownloadsUpdates(enabled)
    }

    func setUpdateCheckInterval(_ interval: TimeInterval) {
        updateService?.setUpdateCheckInterval(interval)
    }
}
