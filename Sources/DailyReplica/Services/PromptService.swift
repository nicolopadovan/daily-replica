import DailyReplicaCore
import Foundation

@MainActor
final class PromptService {
    private let state: AppState
    private let libraryService: LibraryService
    private var promptEngine: SmartPromptEngine
    weak var presenter: PromptPresenting?

    init(
        state: AppState,
        libraryService: LibraryService,
        promptEngine: SmartPromptEngine = SmartPromptEngine()
    ) {
        self.state = state
        self.libraryService = libraryService
        self.promptEngine = promptEngine
    }

    func showPromptIfNeeded(now: Date) {
        guard state.activePrompt == nil, let latest = state.todaySegments.last else {
            return
        }
        guard let prompt = promptEngine.evaluate(segment: latest, currentContext: state.currentContext, now: now) else {
            return
        }
        promptEngine.recordPrompt(prompt, at: now)
        state.activePrompt = prompt
        presenter?.showPrompt(prompt)
    }

    func createRule(from prompt: SmartPrompt, categoryID: String) {
        if let host = prompt.urlHost {
            libraryService.addRule(kind: .chromeHost, pattern: host, categoryID: categoryID)
        } else if let bundleID = prompt.appBundleID {
            libraryService.addRule(kind: .appBundleID, pattern: bundleID, categoryID: categoryID)
        }
        dismissPrompt()
    }

    func dismissPrompt() {
        state.activePrompt = nil
        presenter?.dismissPrompt()
    }
}
