import SwiftUI

@main
struct DailyReplicaApp: App {
    @StateObject private var coordinator = AppCoordinator()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: coordinator.menuBarViewModel)
                .bindWindowActions(to: coordinator)
        } label: {
            Label(coordinator.menuTitle, systemImage: coordinator.menuSystemImage)
        }
        .menuBarExtraStyle(.window)

        Window("Today", id: "today") {
            TodayView(viewModel: coordinator.todayViewModel)
                .bindWindowActions(to: coordinator)
                .frame(minWidth: 1080, minHeight: 620)
        }

        Window("Settings", id: "settings") {
            SettingsView(viewModel: coordinator.settingsViewModel)
                .bindWindowActions(to: coordinator)
                .frame(minWidth: 760, minHeight: 560)
        }
    }
}
