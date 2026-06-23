import DailyReplicaCore
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedSegmentID: UUID?

    private var selectedSegment: ActivitySegment? {
        if let selectedSegmentID,
           let segment = model.todaySegments.first(where: { $0.id == selectedSegmentID }) {
            return segment
        }
        return model.todaySegments.last
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 18) {
                journalHeader

                VStack(alignment: .leading, spacing: 10) {
                    JournalSectionHeader(title: "Day ribbon", detail: Date().formatted(date: .abbreviated, time: .omitted))
                    DayRibbonView(
                        entries: model.todayRibbonEntries,
                        selectedSegmentID: selectedSegment?.id,
                        height: 20,
                        onSelect: { selectedSegmentID = $0 }
                    )
                    ribbonLegend
                }
                .journalSurface()

                if model.todaySegments.isEmpty {
                    EmptyJournalState(
                        title: "No activity yet",
                        message: "Start tracking from the menu bar and your day will appear here.",
                        systemImage: "clock.badge"
                    )
                } else {
                    timeline
                }
            }
            .padding(22)
            .background(CalmPalette.porcelain.opacity(0.55))
            .navigationSplitViewColumnWidth(min: 640, ideal: 780)
        } detail: {
            SegmentInspector(segment: selectedSegment)
                .environmentObject(model)
                .frame(minWidth: 320, maxWidth: 400, maxHeight: .infinity)
                .background(.background)
        }
        .onAppear {
            model.reloadToday()
            selectedSegmentID = selectedSegmentID ?? model.todaySegments.last?.id
        }
        .onChange(of: model.todaySegments.count) { _, _ in
            if selectedSegmentID == nil {
                selectedSegmentID = model.todaySegments.last?.id
            }
        }
    }

    private var journalHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Today")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(model.currentContext?.name ?? "No current project")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                CategoryPill(
                    title: model.isTracking ? "Tracking" : "Paused",
                    categoryID: model.isTracking ? CategoryID.work.rawValue : CategoryID.unclassified.rawValue,
                    systemImage: model.isTracking ? "record.circle.fill" : "pause.circle.fill"
                )
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                MetricTile(title: "Tracked", value: DurationFormatter.format(model.todaySummary.totalDuration), tint: CalmPalette.cypress, symbol: "clock")
                MetricTile(title: "Active", value: DurationFormatter.format(model.todaySummary.activeDuration), tint: CalmPalette.signalBlue, symbol: "bolt.fill")
                MetricTile(title: "Inactive", value: DurationFormatter.format(model.todaySummary.inactiveDuration), tint: CalmPalette.graphite, symbol: "moon.zzz.fill")
                MetricTile(title: "Unsorted", value: DurationFormatter.format(model.todaySummary.unclassifiedDuration), tint: CalmPalette.persimmon, symbol: "tag.slash.fill")
            }
        }
        .journalSurface(padding: 18)
    }

    private var ribbonLegend: some View {
        HStack(spacing: 12) {
            ForEach(model.todaySummary.topCategories(limit: 5)) { item in
                HStack(spacing: 5) {
                    CategoryDot(categoryID: item.categoryID)
                    Text(model.displayName(for: item.categoryID))
                        .lineLimit(1)
                    Text(DurationFormatter.format(item.duration))
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
            Spacer(minLength: 0)
        }
    }

    private var timeline: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(model.todaySegments.reversed()) { segment in
                    TimelineSegmentRow(
                        segment: segment,
                        isSelected: selectedSegment?.id == segment.id,
                        onSelect: { selectedSegmentID = segment.id }
                    )
                    .environmentObject(model)
                }
            }
            .padding(.bottom, 12)
        }
    }
}

struct TimelineSegmentRow: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    let segment: ActivitySegment
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(CalmPalette.categoryColor(segment.categoryID))
                .frame(width: 4)
                .clipShape(Capsule())

            AppIconBadge(bundleID: segment.appBundleID, appName: segment.appName, size: 38)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(primaryTitle)
                            .font(.system(size: 15, weight: .semibold))
                            .lineLimit(1)
                        Text(timeRange)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(DurationFormatter.format(segment.duration))
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    categoryMenu
                    contextMenu
                    if segment.hasManualOverride {
                        CategoryPill(title: "Edited", categoryID: segment.categoryID, systemImage: "pencil")
                    }
                }

                if let detail = detailText {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? CalmPalette.cypress.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onSelect)
    }

    private var rowBackground: Color {
        isSelected ? CalmPalette.cypress.opacity(0.08) : Color(nsColor: .controlBackgroundColor).opacity(0.68)
    }

    private var primaryTitle: String {
        if segment.state == .inactive {
            return "Inactive"
        }
        return segment.appName ?? segment.appBundleID ?? "Unknown app"
    }

    private var detailText: String? {
        if let windowTitle = segment.windowTitle, !windowTitle.isEmpty {
            if let host = segment.urlHost {
                return "\(windowTitle) · \(host)"
            }
            return windowTitle
        }
        return segment.urlHost
    }

    private var timeRange: String {
        "\(segment.start.formatted(date: .omitted, time: .shortened)) - \(segment.end.formatted(date: .omitted, time: .shortened))"
    }

    private var categoryMenu: some View {
        Menu {
            ForEach(model.categories) { category in
                Button(category.name) {
                    model.editSegmentCategory(segmentID: segment.id, categoryID: category.id)
                }
            }
            Divider()
            Button("Create new category...") {
                openWindow(id: "settings")
            }
        } label: {
            CategoryPill(title: model.displayName(for: segment.categoryID), categoryID: segment.categoryID)
        }
        .menuStyle(.borderlessButton)
    }

    private var contextMenu: some View {
        Menu {
            Button("No project") {
                model.editSegmentContext(segmentID: segment.id, contextID: nil)
            }
            ForEach(model.contexts) { context in
                Button(context.name) {
                    model.editSegmentContext(segmentID: segment.id, contextID: context.id)
                }
            }
            Divider()
            Button("Create new project...") {
                openWindow(id: "settings")
            }
        } label: {
            Label(segment.contextName ?? "No project", systemImage: "folder.fill")
                .font(.caption.weight(.medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(CalmPalette.mist.opacity(0.55), in: Capsule())
        }
        .menuStyle(.borderlessButton)
    }
}

struct SegmentInspector: View {
    @EnvironmentObject private var model: AppModel
    @State private var isCreatingCategory = false
    @State private var isCreatingProject = false
    @State private var newCategoryName = ""
    @State private var newProjectName = ""
    @State private var newProjectCategoryID = CategoryID.work.rawValue
    let segment: ActivitySegment?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let segment {
                header(for: segment)
                Divider()
                correctionControls(for: segment)
                metadata(for: segment)
                Spacer()
            } else {
                EmptyJournalState(
                    title: "Select a segment",
                    message: "Choose a row to see details and fix its category or project.",
                    systemImage: "sidebar.right"
                )
                .padding(20)
                Spacer()
            }
        }
        .padding(22)
    }

    private func header(for segment: ActivitySegment) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                AppIconBadge(bundleID: segment.appBundleID, appName: segment.appName, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(segment.state == .inactive ? "Inactive" : (segment.appName ?? "Unknown app"))
                        .font(.title3.bold())
                        .lineLimit(1)
                    Text(DurationFormatter.format(segment.duration))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            DayRibbonView(
                entries: ActivityDayPresenter.ribbonEntries(for: [segment], in: DateInterval(start: segment.start, end: segment.end)),
                selectedSegmentID: segment.id,
                height: 12
            )
        }
    }

    private func correctionControls(for segment: ActivitySegment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            JournalSectionHeader(title: "Fix this time entry", detail: segment.hasManualOverride ? "edited" : nil)

            VStack(alignment: .leading, spacing: 5) {
                Text("What kind of activity was this?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Category", selection: categoryBinding(for: segment)) {
                    ForEach(model.categories) { category in
                        Text(category.name).tag(category.id)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Which project should it count toward?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Project", selection: contextBinding(for: segment)) {
                    Text("No project").tag("")
                    ForEach(model.contexts) { context in
                        Text(context.name).tag(context.id.uuidString)
                    }
                }
            }

            HStack {
                Button {
                    isCreatingCategory.toggle()
                } label: {
                    Label("Create category", systemImage: "plus.circle")
                }
                Button {
                    isCreatingProject.toggle()
                } label: {
                    Label("Create project", systemImage: "plus.circle")
                }
            }
            .font(.caption)

            if isCreatingCategory {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("New category name", text: $newCategoryName)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancel") {
                            isCreatingCategory = false
                            newCategoryName = ""
                        }
                        Spacer()
                        Button("Create and use") {
                            if let category = model.addCategory(name: newCategoryName) {
                                model.editSegmentCategory(segmentID: segment.id, categoryID: category.id)
                            }
                            isCreatingCategory = false
                            newCategoryName = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CalmPalette.cypress)
                    }
                }
                .padding(10)
                .background(CalmPalette.mist.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if isCreatingProject {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("New project name", text: $newProjectName)
                        .textFieldStyle(.roundedBorder)
                    Picker("Usual category", selection: $newProjectCategoryID) {
                        ForEach(model.categories.filter { $0.id != CategoryID.inactive.rawValue }) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    HStack {
                        Button("Cancel") {
                            isCreatingProject = false
                            newProjectName = ""
                        }
                        Spacer()
                        Button("Create and use") {
                            if let context = model.addContext(name: newProjectName, defaultCategoryID: newProjectCategoryID) {
                                model.editSegmentContext(segmentID: segment.id, contextID: context.id)
                            }
                            isCreatingProject = false
                            newProjectName = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CalmPalette.cypress)
                    }
                }
                .padding(10)
                .background(CalmPalette.mist.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .journalSurface()
    }

    private func metadata(for segment: ActivitySegment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            JournalSectionHeader(title: "Details")
            InspectorRow(label: "Time", value: "\(segment.start.formatted(date: .omitted, time: .shortened)) - \(segment.end.formatted(date: .omitted, time: .shortened))")
            InspectorRow(label: "Category", value: model.displayName(for: segment.categoryID))
            InspectorRow(label: "Project", value: segment.contextName ?? "None")
            if let bundleID = segment.appBundleID {
                InspectorRow(label: "Bundle", value: bundleID)
            }
            if let host = segment.urlHost {
                InspectorRow(label: "Host", value: host)
            }
            if let windowTitle = segment.windowTitle, !windowTitle.isEmpty {
                InspectorRow(label: "Window", value: windowTitle)
            }
        }
        .journalSurface()
    }

    private func categoryBinding(for segment: ActivitySegment) -> Binding<String> {
        Binding(
            get: { segment.categoryID },
            set: { model.editSegmentCategory(segmentID: segment.id, categoryID: $0) }
        )
    }

    private func contextBinding(for segment: ActivitySegment) -> Binding<String> {
        Binding(
            get: { segment.contextID?.uuidString ?? "" },
            set: { model.editSegmentContext(segmentID: segment.id, contextID: UUID(uuidString: $0)) }
        )
    }
}

private struct InspectorRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}

enum DurationFormatter {
    static func format(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        if minutes > 0 {
            return "\(minutes)m \(remainingSeconds)s"
        }
        return "\(remainingSeconds)s"
    }
}
