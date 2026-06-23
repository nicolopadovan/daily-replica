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

        Window("Daily Replica", id: "main") {
            MainWindowView(coordinator: coordinator)
                .bindWindowActions(to: coordinator)
                .frame(minWidth: 1_240, minHeight: 620)
        }
    }
}

private struct MainWindowView: View {
    @ObservedObject var coordinator: AppCoordinator

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .background(CalmPalette.porcelain.opacity(0.3))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Daily Replica")
                    .font(.title2.bold())
                Text("Track, organize, and teach.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 12)

            ForEach(AppSection.allCases) { section in
                Button {
                    coordinator.select(section)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: section.systemImage)
                            .frame(width: 18)
                            .foregroundStyle(coordinator.selectedSection == section ? CalmPalette.cypress : .secondary)
                        Text(section.title)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        coordinator.selectedSection == section ? CalmPalette.cypress.opacity(0.11) : .clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 210)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var content: some View {
        switch coordinator.selectedSection {
        case .today:
            TodayView(viewModel: coordinator.todayViewModel)
        case .analytics:
            AnalyticsView(viewModel: coordinator.analyticsViewModel)
        case .contexts, .categories, .rules, .permissions, .updates:
            SettingsView(viewModel: coordinator.settingsViewModel, showsSidebar: false)
        }
    }
}
