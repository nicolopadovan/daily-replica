import DailyReplicaCore
import Foundation

@MainActor
final class TrackingService {
    private let store: ActivityStore
    private let state: AppState
    private let sampler: ActivitySampling
    private let permissionChecker: PermissionChecking
    private let promptService: PromptService
    private let eventObserver: ActivityEventObserving?
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
        handleEvent(.heartbeat)

        let timer = Timer(timeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleEvent(.heartbeat)
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stopTracking() {
        timer?.invalidate()
        timer = nil
        eventObserver?.stop()
        eventObserver?.onEvent = nil
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
        state.accessibilityTrusted = permissionChecker.isAccessibilityTrusted(prompt: false)
        let focus = sampler.sample(now: now, accessibilityTrusted: state.accessibilityTrusted)
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
