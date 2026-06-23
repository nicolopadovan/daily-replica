import AppKit
import DailyReplicaCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var isTracking = false
    @Published var categories: [CategoryDefinition] = CategoryID.builtInDefinitions
    @Published var contexts: [ProjectContext] = []
    @Published var currentContextID: UUID?
    @Published var rules: [ClassificationRule] = []
    @Published var todaySegments: [ActivitySegment] = []
    @Published var activePrompt: SmartPrompt?
    @Published var lastError: String?
    @Published var lastSampleDescription = "Not tracking"
    @Published var accessibilityTrusted = PermissionService.isAccessibilityTrusted(prompt: false)

    private let store: SQLiteActivityStore
    private let classifier = ActivityClassifier()
    private let reducer = ActivitySegmentReducer()
    private let sampler = SystemActivitySampler(idleThreshold: 30)
    private let promptPanel = PromptPanelController()
    private var promptEngine = SmartPromptEngine()
    private var timer: Timer?

    init() {
        do {
            store = try SQLiteActivityStore(path: Self.defaultStorePath())
            loadState()
        } catch {
            fatalError("Daily Replica could not open its local store: \(error)")
        }
    }

    var currentContext: ProjectContext? {
        guard let currentContextID else {
            return nil
        }
        return contexts.first(where: { $0.id == currentContextID })
    }

    var todayInterval: DateInterval {
        DateInterval.day(containing: Date())
    }

    var todaySummary: ActivityDaySummary {
        ActivityDayPresenter.summary(for: todaySegments, in: todayInterval)
    }

    var todayRibbonEntries: [ActivityRibbonEntry] {
        ActivityDayPresenter.ribbonEntries(for: todaySegments, in: todayInterval)
    }

    var latestSegment: ActivitySegment? {
        todaySegments.last
    }

    var latestSegmentElapsed: TimeInterval {
        guard let latestSegment else {
            return 0
        }
        return max(0, Date().timeIntervalSince(latestSegment.start))
    }

    func startTracking() {
        guard !isTracking else {
            return
        }
        isTracking = true
        captureTick()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.captureTick()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
        isTracking = false
        lastSampleDescription = "Not tracking"
    }

    func setCurrentContext(id: UUID?) {
        currentContextID = id
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: "currentContextID")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentContextID")
        }
    }

    @discardableResult
    func addContext(name: String, defaultCategoryID: String?) -> ProjectContext? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        let context = ProjectContext(name: trimmed, defaultCategoryID: defaultCategoryID)
        do {
            try store.upsertContext(context)
            contexts.append(context)
            contexts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            setCurrentContext(id: context.id)
            return context
        } catch {
            lastError = error.localizedDescription
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
        guard !categories.contains(where: { $0.id == category.id }) else {
            return categories.first(where: { $0.id == category.id })
        }
        do {
            try store.upsertCategory(category)
            categories.append(category)
            categories.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return category
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func archiveContext(id: UUID) {
        guard let index = contexts.firstIndex(where: { $0.id == id }) else {
            return
        }
        var context = contexts[index]
        context.isArchived = true
        do {
            try store.upsertContext(context)
            contexts.remove(at: index)
            if currentContextID == id {
                setCurrentContext(id: contexts.first?.id)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func addRule(kind: ClassificationRuleKind, pattern: String, categoryID: String) {
        let normalized = ClassificationRule.normalizedPattern(pattern, kind: kind)
        guard !normalized.isEmpty else {
            return
        }
        let rule = ClassificationRule(kind: kind, pattern: normalized, categoryID: categoryID)
        do {
            try store.upsertRule(rule)
            rules.append(rule)
            rules.sort { $0.pattern.localizedCaseInsensitiveCompare($1.pattern) == .orderedAscending }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteRule(id: UUID) {
        do {
            try store.deleteRule(id: id)
            rules.removeAll { $0.id == id }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func editSegmentCategory(segmentID: UUID, categoryID: String) {
        reducer.editSegment(id: segmentID, in: &todaySegments, categoryID: categoryID)
        persistSegment(id: segmentID)
    }

    func editSegmentContext(segmentID: UUID, contextID: UUID?) {
        guard let index = todaySegments.firstIndex(where: { $0.id == segmentID }) else {
            return
        }
        var segment = todaySegments[index]
        if let contextID, let context = contexts.first(where: { $0.id == contextID }) {
            segment = segment.applyingManualEdit(context: context)
        } else {
            segment.contextID = nil
            segment.contextName = nil
            segment.manualContextID = nil
            segment.updatedAt = Date()
        }
        todaySegments[index] = segment
        persistSegment(id: segmentID)
    }

    func createRule(from prompt: SmartPrompt, categoryID: String) {
        if let host = prompt.urlHost {
            addRule(kind: .chromeHost, pattern: host, categoryID: categoryID)
        } else if let bundleID = prompt.appBundleID {
            addRule(kind: .appBundleID, pattern: bundleID, categoryID: categoryID)
        }
        dismissPrompt()
    }

    func dismissPrompt() {
        activePrompt = nil
        promptPanel.close()
    }

    func requestAccessibilityPermission() {
        accessibilityTrusted = PermissionService.isAccessibilityTrusted(prompt: true)
    }

    func reloadToday() {
        do {
            todaySegments = try store.fetchSegments(in: DateInterval.day(containing: Date()))
        } catch {
            lastError = error.localizedDescription
        }
    }

    func displayName(for categoryID: String) -> String {
        categories.first(where: { $0.id == categoryID })?.name ?? categoryID
    }

    private func captureTick() {
        let now = Date()
        accessibilityTrusted = PermissionService.isAccessibilityTrusted(prompt: false)
        let focus = sampler.sample(now: now, accessibilityTrusted: accessibilityTrusted)
        let result = classifier.classify(focus, rules: rules)
        let context = currentContext
        let classified = ClassifiedSample(
            focus: focus,
            categoryID: result.categoryID,
            contextID: context?.id,
            contextName: context?.name
        )

        reducer.ingest(classified, into: &todaySegments)
        for segment in todaySegments.suffix(2) {
            do {
                try store.upsertSegment(segment)
            } catch {
                lastError = error.localizedDescription
            }
        }

        lastSampleDescription = sampleSummary(focus: focus, categoryID: result.categoryID)
        showPromptIfNeeded(now: now)
    }

    private func showPromptIfNeeded(now: Date) {
        guard activePrompt == nil, let latest = todaySegments.last else {
            return
        }
        guard let prompt = promptEngine.evaluate(segment: latest, currentContext: currentContext, now: now) else {
            return
        }
        promptEngine.recordPrompt(prompt, at: now)
        activePrompt = prompt
        promptPanel.show(prompt: prompt, model: self)
    }

    private func persistSegment(id: UUID) {
        guard let segment = todaySegments.first(where: { $0.id == id }) else {
            return
        }
        do {
            try store.upsertSegment(segment)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func loadState() {
        do {
            categories = try store.fetchCategories()
            contexts = try store.fetchContexts()
            if contexts.isEmpty {
                let general = ProjectContext(name: "General", defaultCategoryID: CategoryID.work.rawValue)
                try store.upsertContext(general)
                contexts = [general]
            }
            rules = try store.fetchRules()
            if let saved = UserDefaults.standard.string(forKey: "currentContextID"),
               let id = UUID(uuidString: saved),
               contexts.contains(where: { $0.id == id }) {
                currentContextID = id
            } else {
                currentContextID = contexts.first?.id
            }
            reloadToday()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func sampleSummary(focus: FocusSample, categoryID: String) -> String {
        if focus.state == .inactive {
            return "Inactive"
        }

        var parts: [String] = [focus.appName ?? "Unknown app", displayName(for: categoryID)]
        if let host = focus.urlHost {
            parts.append(host)
        }
        return parts.joined(separator: " · ")
    }

    private static func defaultStorePath() -> String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("DailyReplica", isDirectory: true)
            .appendingPathComponent("activity.sqlite")
            .path
    }

    private static func slug(for name: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let parts = name.lowercased().unicodeScalars.split { !allowed.contains($0) }
        let slug = parts.map(String.init).joined(separator: "-")
        return slug.isEmpty ? UUID().uuidString : slug
    }
}
