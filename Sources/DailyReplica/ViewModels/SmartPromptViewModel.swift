import AppKit
import Combine
import DailyReplicaCore
import Foundation

@MainActor
final class SmartPromptViewModel: ObservableObject {
    @Published var selectedCategoryID: String

    let prompt: SmartPrompt
    private let state: AppState
    private let promptService: PromptService
    private weak var coordinator: AppCoordinating?
    private var stateCancellable: AnyCancellable?

    init(
        prompt: SmartPrompt,
        state: AppState,
        promptService: PromptService,
        coordinator: AppCoordinating
    ) {
        self.prompt = prompt
        self.state = state
        self.promptService = promptService
        self.coordinator = coordinator
        self.selectedCategoryID = prompt.suggestedCategoryID ?? CategoryID.work.rawValue
        stateCancellable = state.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var isUnclassifiedActivity: Bool {
        prompt.kind == .unclassifiedActivity
    }

    var title: String { prompt.title }
    var message: String { prompt.message }
    var subtitle: String { prompt.appName ?? prompt.urlHost ?? "Current activity" }

    var iconName: String {
        isUnclassifiedActivity ? "tag.fill" : "arrow.triangle.branch"
    }

    var iconCategoryID: String {
        isUnclassifiedActivity ? CategoryID.browsing.rawValue : CategoryID.work.rawValue
    }

    var assignableCategories: [CategoryDefinition] {
        state.categories.filter { $0.id != CategoryID.inactive.rawValue }
    }

    func dismiss() {
        promptService.dismissPrompt()
    }

    func rememberChoice() {
        promptService.createRule(from: prompt, categoryID: selectedCategoryID)
    }

    func reviewToday() {
        promptService.dismissPrompt()
        NSApp.activate()
        coordinator?.openToday()
    }

    func keepContext() {
        promptService.dismissPrompt()
    }
}
