import AppKit
import Foundation

@MainActor
final class WorkspaceActivityEventObserver: ActivityEventObserving {
    var onEvent: ((TrackingEvent) -> Void)?

    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.notificationCenter = notificationCenter
    }

    func start() {
        guard observers.isEmpty else {
            return
        }

        observe(NSWorkspace.didActivateApplicationNotification, event: .appActivated)
        observe(NSWorkspace.didTerminateApplicationNotification, event: .appTerminated)
        observe(NSWorkspace.willSleepNotification, event: .willSleep)
        observe(NSWorkspace.didWakeNotification, event: .didWake)
        observe(NSWorkspace.screensDidSleepNotification, event: .screensDidSleep)
        observe(NSWorkspace.screensDidWakeNotification, event: .screensDidWake)
        observe(NSWorkspace.sessionDidResignActiveNotification, event: .sessionDidResignActive)
        observe(NSWorkspace.sessionDidBecomeActiveNotification, event: .sessionDidBecomeActive)
    }

    func stop() {
        observers.forEach(notificationCenter.removeObserver)
        observers.removeAll()
    }

    private func observe(_ name: NSNotification.Name, event: TrackingEvent) {
        let observer = notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.onEvent?(event)
            }
        }
        observers.append(observer)
    }
}
