import Foundation
import Sparkle

@MainActor
final class UpdateService: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    @Published private(set) var allowsAutomaticUpdates = false
    @Published private(set) var updateCheckInterval: TimeInterval = 86_400
    @Published private(set) var feedURL: URL?

    private let updaterController: SPUStandardUpdaterController?
    private let updateDriverDelegate: UpdateGentleReminderDelegate?
    private var observations: [NSKeyValueObservation] = []

    var isConfigured: Bool {
        updaterController != nil
    }

    init() {
        guard Self.hasUsableSparkleConfiguration else {
            updaterController = nil
            return
        }

        let driverDelegate = UpdateGentleReminderDelegate()
        updateDriverDelegate = driverDelegate

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: driverDelegate
        )
        updaterController = controller
        observations = [
            controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                Task { @MainActor in self?.canCheckForUpdates = updater.canCheckForUpdates }
            },
            controller.updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                Task { @MainActor in self?.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates }
            },
            controller.updater.observe(\.automaticallyDownloadsUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                Task { @MainActor in self?.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates }
            },
            controller.updater.observe(\.allowsAutomaticUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                Task { @MainActor in self?.allowsAutomaticUpdates = updater.allowsAutomaticUpdates }
            },
            controller.updater.observe(\.updateCheckInterval, options: [.initial, .new]) { [weak self] updater, _ in
                Task { @MainActor in self?.updateCheckInterval = updater.updateCheckInterval }
            }
        ]
        feedURL = controller.updater.feedURL
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    func setAutomaticallyChecksForUpdates(_ enabled: Bool) {
        updaterController?.updater.automaticallyChecksForUpdates = enabled
    }

    func setAutomaticallyDownloadsUpdates(_ enabled: Bool) {
        updaterController?.updater.automaticallyDownloadsUpdates = enabled
    }

    func setUpdateCheckInterval(_ interval: TimeInterval) {
        updaterController?.updater.updateCheckInterval = interval
    }

    private static var hasUsableSparkleConfiguration: Bool {
        guard
            let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
            !publicKey.isEmpty,
            !publicKey.contains("$("),
            !publicKey.contains("__")
        else {
            return false
        }
        return true
    }
}

private final class UpdateGentleReminderDelegate: NSObject, SPUStandardUserDriverDelegate {
    // ponytail: this exists to declare support for Sparkle gentle reminders for backgrounded checks.
    var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    func standardUserDriverShouldHandleShowingScheduledUpdate(_ handleShowingUpdate: Bool, andInImmediateFocus immediateFocus: Bool) -> Bool {
        false
    }
}
