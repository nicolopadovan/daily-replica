import Foundation

public struct IdleClassifier: Sendable {
    public var threshold: TimeInterval

    public init(threshold: TimeInterval = 30) {
        self.threshold = threshold
    }

    public func state(forIdleTime idleTime: TimeInterval) -> ActivityState {
        idleTime >= threshold ? .inactive : .active
    }
}
