import SwiftUI

@main
struct DailyReplicaApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(model)
        } label: {
            Label(menuTitle, systemImage: model.isTracking ? "record.circle.fill" : "pause.circle")
        }
        .menuBarExtraStyle(.window)

        Window("Today", id: "today") {
            TodayView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 620)
        }

        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(model)
                .frame(minWidth: 760, minHeight: 560)
            }
    }

    private var menuTitle: String {
        if model.latestSegment?.state == .inactive {
            return "Inactive"
        }
        return model.currentContext?.name ?? "Daily Replica"
    }
}
