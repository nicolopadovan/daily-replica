import DailyReplicaCore
@testable import DailyReplica
import XCTest

@MainActor
final class AppHealthChecksTests: XCTestCase {
    func testAppLaunchAutoStartsTracking() async {
        let coordinator = AppCoordinator()
        defer {
            if coordinator.state.isTracking {
                coordinator.menuBarViewModel.toggleTracking()
            }
        }

        try? await Task.sleep(nanoseconds: 120_000_000)

        XCTAssertTrue(
            coordinator.state.isTracking,
            "App launch should initialize tracking automatically."
        )
    }

    func testStopTrackingThenResumeSameAppKeepsPausedTimeAsInactive() {
        let harness = AppHarness()
        harness.sampler.sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 100),
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode"
        )

        harness.trackingService.captureTick(now: Date(timeIntervalSince1970: 100))
        harness.state.isTracking = true
        harness.trackingService.stopTracking(now: Date(timeIntervalSince1970: 160))

        harness.sampler.sample = FocusSample(
            timestamp: Date(timeIntervalSince1970: 220),
            state: .active,
            appBundleID: "com.apple.dt.Xcode",
            appName: "Xcode"
        )
        harness.trackingService.captureTick(now: Date(timeIntervalSince1970: 220))

        XCTAssertEqual(harness.state.todaySegments.count, 3)
        XCTAssertEqual(
            harness.state.todaySegments.map(\.state),
            [ActivityState.active, ActivityState.inactive, ActivityState.active]
        )
        XCTAssertNil(harness.state.todaySegments[1].appBundleID)
        XCTAssertNil(harness.state.todaySegments[1].appName)
        XCTAssertEqual(harness.state.todaySegments[1].start, Date(timeIntervalSince1970: 160))
        XCTAssertEqual(harness.state.todaySegments[1].end, Date(timeIntervalSince1970: 220))
        XCTAssertEqual(harness.state.todaySegments[2].start, Date(timeIntervalSince1970: 220))
        XCTAssertEqual(harness.state.todaySegments[2].appName, "Xcode")
    }
}
