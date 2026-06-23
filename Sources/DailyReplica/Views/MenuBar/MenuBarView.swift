import DailyReplicaCore
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var viewModel: MenuBarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            nowPanel
            dayPanel
            permissionPanel
            actionBar

            if let lastError = viewModel.lastError {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(CalmPalette.rose)
                    .lineLimit(3)
                    .journalSurface(padding: 10)
            }
        }
        .padding(14)
        .frame(width: 360)
        .background(CalmPalette.porcelain.opacity(0.45))
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(viewModel.isTracking ? CalmPalette.cypress : CalmPalette.graphite)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 1) {
                Text("Daily Replica")
                    .font(.headline)
                Text(viewModel.isTracking ? "Tracking now" : "Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.toggleTracking()
            } label: {
                Label(viewModel.isTracking ? "Pause" : "Start", systemImage: viewModel.isTracking ? "pause.fill" : "play.fill")
                    .frame(minWidth: 88)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isTracking ? CalmPalette.persimmon : CalmPalette.cypress)
        }
    }

    private var nowPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            JournalSectionHeader(title: "Now", detail: currentElapsed)

            HStack(spacing: 12) {
                AppIconBadge(
                    bundleID: viewModel.latestSegment?.appBundleID,
                    appName: viewModel.latestSegment?.appName,
                    size: 42
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(currentTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        CategoryPill(
                            title: viewModel.displayName(for: currentCategoryID),
                            categoryID: currentCategoryID
                        )
                        if let host = viewModel.latestSegment?.urlHost {
                            Text(host)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("What are you working on?")
                    .font(.subheadline.weight(.semibold))

                Picker("Project", selection: currentContextBinding) {
                    Text("No project").tag("")
                    ForEach(viewModel.contexts) { context in
                        Text(context.name).tag(context.id.uuidString)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Label("Project time", systemImage: "folder.badge.clock")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.currentProjectElapsed)
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
                .font(.caption)

                if viewModel.isCreatingProject {
                    createProjectForm
                } else {
                    Button {
                        viewModel.showCreateProject()
                    } label: {
                        Label("Create new project", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CalmPalette.cypress)
                }
            }
        }
        .journalSurface()
    }

    private var createProjectForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Project name", text: $viewModel.newProjectName)
                .textFieldStyle(.roundedBorder)

            Picker("Usual category", selection: $viewModel.newProjectCategoryID) {
                ForEach(viewModel.categories.filter { $0.id != CategoryID.inactive.rawValue }) { category in
                    Text(category.name).tag(category.id)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Button("Cancel") {
                    viewModel.cancelCreateProject()
                }
                Spacer()
                Button("Create") {
                    viewModel.createProject()
                }
                .buttonStyle(.borderedProminent)
                .tint(CalmPalette.cypress)
            }
        }
        .padding(10)
        .background(CalmPalette.mist.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var dayPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            JournalSectionHeader(title: "Today", detail: DurationFormatter.format(viewModel.todaySummary.totalDuration))

            DayRibbonView(entries: viewModel.todayRibbonEntries, selectedSegmentID: viewModel.latestSegment?.id, height: 14)

            HStack(spacing: 8) {
                MenuMetric(label: "Active", value: DurationFormatter.format(viewModel.todaySummary.activeDuration), tint: CalmPalette.cypress)
                MenuMetric(label: "Idle", value: DurationFormatter.format(viewModel.todaySummary.inactiveDuration), tint: CalmPalette.graphite)
                MenuMetric(label: "Unsorted", value: DurationFormatter.format(viewModel.todaySummary.unclassifiedDuration), tint: CalmPalette.persimmon)
            }
        }
        .journalSurface()
    }

    @ViewBuilder
    private var permissionPanel: some View {
        if !viewModel.accessibilityTrusted {
            Button {
                viewModel.requestAccessibilityPermission()
            } label: {
                HStack {
                    Image(systemName: "lock.open.trianglebadge.exclamationmark")
                        .foregroundStyle(CalmPalette.persimmon)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable window titles")
                            .font(.subheadline.weight(.semibold))
                        Text("Helps identify what you were doing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .journalSurface(padding: 10)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.openToday()
            } label: {
                Label("Review day", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
            }

            Button {
                viewModel.openSettings()
            } label: {
                Label("Set up", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }

            Button {
                viewModel.quit()
            } label: {
                Image(systemName: "power")
                    .frame(width: 30)
            }
            .help("Quit")
        }
    }

    private var currentTitle: String {
        viewModel.currentTitle
    }

    private var currentCategoryID: String {
        viewModel.currentCategoryID
    }

    private var currentElapsed: String {
        viewModel.currentElapsed
    }

    private var currentContextBinding: Binding<String> {
        Binding(
            get: { viewModel.currentContextID?.uuidString ?? "" },
            set: { value in
                viewModel.setCurrentContext(selection: value)
            }
        )
    }
}

private struct MenuMetric: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#if DEBUG
#Preview("Menu Bar") {
    MenuBarView(viewModel: PreviewFactory.menuBarViewModel())
}

#Preview("Menu Bar Creating Project") {
    MenuBarView(viewModel: PreviewFactory.menuBarViewModel(showingCreateProject: true))
}

#Preview("Menu Metric") {
    MenuMetric(label: "Active", value: "1h 24m", tint: CalmPalette.cypress)
        .frame(width: 120)
        .padding()
}
#endif
