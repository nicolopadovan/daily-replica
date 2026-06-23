import DailyReplicaCore
import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    @State private var isCreatingProject = false
    @State private var newProjectName = ""
    @State private var newProjectCategoryID = CategoryID.work.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            nowPanel
            dayPanel
            permissionPanel
            actionBar

            if let lastError = model.lastError {
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
                .fill(model.isTracking ? CalmPalette.cypress : CalmPalette.graphite)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 1) {
                Text("Daily Replica")
                    .font(.headline)
                Text(model.isTracking ? "Tracking now" : "Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                model.isTracking ? model.stopTracking() : model.startTracking()
            } label: {
                Label(model.isTracking ? "Pause" : "Start", systemImage: model.isTracking ? "pause.fill" : "play.fill")
                    .frame(minWidth: 88)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isTracking ? CalmPalette.persimmon : CalmPalette.cypress)
        }
    }

    private var nowPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            JournalSectionHeader(title: "Now", detail: currentElapsed)

            HStack(spacing: 12) {
                AppIconBadge(
                    bundleID: model.latestSegment?.appBundleID,
                    appName: model.latestSegment?.appName,
                    size: 42
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(currentTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        CategoryPill(
                            title: model.displayName(for: currentCategoryID),
                            categoryID: currentCategoryID
                        )
                        if let host = model.latestSegment?.urlHost {
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
                    ForEach(model.contexts) { context in
                        Text(context.name).tag(context.id.uuidString)
                    }
                }
                .pickerStyle(.menu)

                if isCreatingProject {
                    createProjectForm
                } else {
                    Button {
                        isCreatingProject = true
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
            TextField("Project name", text: $newProjectName)
                .textFieldStyle(.roundedBorder)

            Picker("Usual category", selection: $newProjectCategoryID) {
                ForEach(model.categories.filter { $0.id != CategoryID.inactive.rawValue }) { category in
                    Text(category.name).tag(category.id)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Button("Cancel") {
                    isCreatingProject = false
                    newProjectName = ""
                }
                Spacer()
                Button("Create") {
                    model.addContext(name: newProjectName, defaultCategoryID: newProjectCategoryID)
                    newProjectName = ""
                    isCreatingProject = false
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
            JournalSectionHeader(title: "Today", detail: DurationFormatter.format(model.todaySummary.totalDuration))

            DayRibbonView(entries: model.todayRibbonEntries, selectedSegmentID: model.latestSegment?.id, height: 14)

            HStack(spacing: 8) {
                MenuMetric(label: "Active", value: DurationFormatter.format(model.todaySummary.activeDuration), tint: CalmPalette.cypress)
                MenuMetric(label: "Idle", value: DurationFormatter.format(model.todaySummary.inactiveDuration), tint: CalmPalette.graphite)
                MenuMetric(label: "Unsorted", value: DurationFormatter.format(model.todaySummary.unclassifiedDuration), tint: CalmPalette.persimmon)
            }
        }
        .journalSurface()
    }

    @ViewBuilder
    private var permissionPanel: some View {
        if !model.accessibilityTrusted {
            Button {
                model.requestAccessibilityPermission()
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
                model.reloadToday()
                openWindow(id: "today")
            } label: {
                Label("Review day", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
            }

            Button {
                openWindow(id: "settings")
            } label: {
                Label("Set up", systemImage: "slider.horizontal.3")
                    .frame(maxWidth: .infinity)
            }

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .frame(width: 30)
            }
            .help("Quit")
        }
    }

    private var currentTitle: String {
        if model.latestSegment?.state == .inactive {
            return "Inactive"
        }
        return model.latestSegment?.appName ?? model.lastSampleDescription
    }

    private var currentCategoryID: String {
        model.latestSegment?.categoryID ?? CategoryID.unclassified.rawValue
    }

    private var currentElapsed: String {
        model.latestSegment == nil ? "--" : DurationFormatter.format(model.latestSegmentElapsed)
    }

    private var currentContextBinding: Binding<String> {
        Binding(
            get: { model.currentContextID?.uuidString ?? "" },
            set: { value in
                model.setCurrentContext(id: UUID(uuidString: value))
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
