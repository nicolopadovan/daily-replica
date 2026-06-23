import DailyReplicaCore
import Foundation
import AppKit

@MainActor
final class TrackingService {
    private static let ownBundleIDs = Set(["local.daily-replica.app", Bundle.main.bundleIdentifier].compactMap(\.self))

    private let store: ActivityStore
    private let state: AppState
    private let sampler: ActivitySampling
    private let permissionChecker: PermissionChecking
    private let promptService: PromptService
    private let eventObserver: ActivityEventObserving?
    private let browserURLReader = BrowserURLReader()
    private let heartbeatInterval: TimeInterval
    private let classifier: ActivityClassifier
    private let reducer: ActivitySegmentReducer
    private var timer: Timer?

    init(
        store: ActivityStore,
        state: AppState,
        sampler: ActivitySampling,
        permissionChecker: PermissionChecking,
        promptService: PromptService,
        eventObserver: ActivityEventObserving? = nil,
        heartbeatInterval: TimeInterval = 2,
        classifier: ActivityClassifier = ActivityClassifier(),
        reducer: ActivitySegmentReducer = ActivitySegmentReducer()
    ) {
        self.store = store
        self.state = state
        self.sampler = sampler
        self.permissionChecker = permissionChecker
        self.promptService = promptService
        self.eventObserver = eventObserver
        self.heartbeatInterval = heartbeatInterval
        self.classifier = classifier
        self.reducer = reducer
    }

    func startTracking() {
        guard !state.isTracking else {
            return
        }
        state.isTracking = true
        eventObserver?.onEvent = { [weak self] event in
            self?.handleEvent(event)
        }
        eventObserver?.start()
        appendInactiveGapIfNeeded(at: Date())
        handleEvent(.heartbeat)

        let timer = Timer(timeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleEvent(.heartbeat)
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopTracking(now: Date = Date()) {
        guard state.isTracking else {
            return
        }
        timer?.invalidate()
        timer = nil
        eventObserver?.stop()
        eventObserver?.onEvent = nil
        if let lastSegment = state.todaySegments.last, lastSegment.state != .inactive {
            captureInactiveBoundary(now: now)
        }
        state.isTracking = false
        state.lastSampleDescription = "Not tracking"
    }

    func captureTick(now: Date = Date()) {
        handleEvent(.heartbeat, now: now)
    }

    func handleEvent(_ event: TrackingEvent, now: Date = Date()) {
        switch event {
        case .willSleep, .screensDidSleep, .sessionDidResignActive:
            captureInactiveBoundary(now: now)
        case .heartbeat, .appActivated, .appTerminated, .didWake, .screensDidWake, .sessionDidBecomeActive:
            captureFocusedActivity(now: now)
        }
    }

    private func captureFocusedActivity(now: Date) {
        let accessibilityTrusted = permissionChecker.isAccessibilityTrusted(prompt: false)
        if let frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           BrowserURLReader.supports(bundleID: frontmostBundleID) {
            state.chromeURLsAuthorized = browserURLReader.hasAutomationPermission(for: frontmostBundleID)
        }
        let focus = sampler.sample(now: now, accessibilityTrusted: accessibilityTrusted)
        let capturedExternalWindowTitle = focus.appBundleID.map(Self.ownBundleIDs.contains) != true
            && focus.windowTitle?.isEmpty == false
        state.accessibilityTrusted = accessibilityTrusted || capturedExternalWindowTitle || state.hasObservedWindowTitles
        if focus.appBundleID.map(Self.ownBundleIDs.contains) == true {
            captureInactiveBoundary(now: now)
            return
        }

        let result = classifier.classify(focus, rules: state.rules)
        let context = state.currentContext
        let classified = ClassifiedSample(
            focus: focus,
            categoryID: result.categoryID,
            contextID: context?.id,
            contextName: context?.name
        )

        reducer.ingest(classified, into: &state.todaySegments)
        persistRecentSegments()
        state.lastSampleDescription = sampleSummary(focus: focus, categoryID: result.categoryID)
        promptService.showPromptIfNeeded(now: now)
    }

    private func captureInactiveBoundary(now: Date) {
        let focus = FocusSample(timestamp: now, state: .inactive)
        reducer.ingest(
            ClassifiedSample(focus: focus, categoryID: CategoryID.inactive.rawValue),
            into: &state.todaySegments
        )
        persistRecentSegments()
        state.lastSampleDescription = "Inactive"
    }

    private func appendInactiveGapIfNeeded(at now: Date) {
        guard let lastSegment = state.todaySegments.last, lastSegment.state == .active else {
            return
        }
        guard now > lastSegment.end else {
            return
        }

        reducer.ingest(
            ClassifiedSample(
                focus: FocusSample(timestamp: now, state: .inactive),
                categoryID: CategoryID.inactive.rawValue
            ),
            into: &state.todaySegments
        )
        persistRecentSegments()
    }

    private func persistRecentSegments() {
        for segment in state.todaySegments.suffix(2) {
            do {
                try store.upsertSegment(segment)
            } catch {
                state.lastError = error.localizedDescription
            }
        }
    }

    private func sampleSummary(focus: FocusSample, categoryID: String) -> String {
        if focus.state == .inactive {
            return "Inactive"
        }

        var parts = [focus.appName ?? "Unknown app", state.displayName(for: categoryID)]
        if let host = focus.urlHost {
            parts.append(host)
        }
        return parts.joined(separator: " · ")
    }
}
