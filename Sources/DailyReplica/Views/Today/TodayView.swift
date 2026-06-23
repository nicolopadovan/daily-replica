import DailyReplicaCore
import SwiftUI

struct TodayView: View {
    @ObservedObject var viewModel: TodayViewModel

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 18) {
                journalHeader

                VStack(alignment: .leading, spacing: 10) {
                    JournalSectionHeader(title: "Day ribbon", detail: Date().formatted(date: .abbreviated, time: .omitted))
                    DayRibbonView(
                        entries: viewModel.todayRibbonEntries,
                        selectedSegmentID: viewModel.selectedSegment?.id,
                        height: 20,
                        onSelect: { viewModel.selectSegment(id: $0) }
                    )
                    ribbonLegend
                }
                .journalSurface()

                if viewModel.todaySegments.isEmpty {
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
            SegmentInspector(viewModel: viewModel, segment: viewModel.selectedSegment)
                .frame(minWidth: 320, maxWidth: 400, maxHeight: .infinity)
                .background(.background)
        }
        .onAppear {
            viewModel.reloadToday()
        }
        .onChange(of: viewModel.todaySegments.count) { _, _ in
            viewModel.selectLatestIfNeeded()
        }
    }

    private var journalHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Today")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(viewModel.currentContextName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                CategoryPill(
                    title: viewModel.isTracking ? "Tracking" : "Paused",
                    categoryID: viewModel.isTracking ? CategoryID.work.rawValue : CategoryID.unclassified.rawValue,
                    systemImage: viewModel.isTracking ? "record.circle.fill" : "pause.circle.fill"
                )
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                MetricTile(title: "Tracked", value: DurationFormatter.format(viewModel.todaySummary.totalDuration), tint: CalmPalette.cypress, symbol: "clock")
                MetricTile(title: "Active", value: DurationFormatter.format(viewModel.todaySummary.activeDuration), tint: CalmPalette.signalBlue, symbol: "bolt.fill")
                MetricTile(title: "Inactive", value: DurationFormatter.format(viewModel.todaySummary.inactiveDuration), tint: CalmPalette.graphite, symbol: "moon.zzz.fill")
                MetricTile(title: "Unsorted", value: DurationFormatter.format(viewModel.todaySummary.unclassifiedDuration), tint: CalmPalette.persimmon, symbol: "tag.slash.fill")
            }
        }
        .journalSurface(padding: 18)
    }

    private var ribbonLegend: some View {
        HStack(spacing: 12) {
            ForEach(viewModel.todaySummary.topCategories(limit: 5)) { item in
                HStack(spacing: 5) {
                    CategoryDot(categoryID: item.categoryID)
                    Text(viewModel.displayName(for: item.categoryID))
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
                ForEach(viewModel.todaySegments.reversed()) { segment in
                    TimelineSegmentRow(
                        viewModel: viewModel,
                        segment: segment,
                        isSelected: viewModel.selectedSegment?.id == segment.id,
                        onSelect: { viewModel.selectSegment(id: segment.id) }
                    )
                }
            }
            .padding(.bottom, 12)
        }
    }
}

struct TimelineSegmentRow: View {
    @ObservedObject var viewModel: TodayViewModel
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
            ForEach(viewModel.categories) { category in
                Button(category.name) {
                    viewModel.editSegmentCategory(segmentID: segment.id, categoryID: category.id)
                }
            }
            Divider()
            Button("Create new category...") {
                viewModel.openSettings()
            }
        } label: {
            CategoryPill(title: viewModel.displayName(for: segment.categoryID), categoryID: segment.categoryID)
        }
        .menuStyle(.borderlessButton)
    }

    private var contextMenu: some View {
        Menu {
            Button("No project") {
                viewModel.editSegmentContext(segmentID: segment.id, contextID: nil)
            }
            ForEach(viewModel.contexts) { context in
                Button(context.name) {
                    viewModel.editSegmentContext(segmentID: segment.id, contextID: context.id)
                }
            }
            Divider()
            Button("Create new project...") {
                viewModel.openSettings()
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
    @ObservedObject var viewModel: TodayViewModel
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
                    ForEach(viewModel.categories) { category in
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
                    ForEach(viewModel.contexts) { context in
                        Text(context.name).tag(context.id.uuidString)
                    }
                }
            }

            HStack {
                Button {
                    viewModel.toggleCategoryCreation()
                } label: {
                    Label("Create category", systemImage: "plus.circle")
                }
                Button {
                    viewModel.toggleProjectCreation()
                } label: {
                    Label("Create project", systemImage: "plus.circle")
                }
            }
            .font(.caption)

            if viewModel.isCreatingCategory {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("New category name", text: $viewModel.newCategoryName)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Cancel") {
                            viewModel.cancelCategoryCreation()
                        }
                        Spacer()
                        Button("Create and use") {
                            viewModel.createCategoryAndUse(segmentID: segment.id)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CalmPalette.cypress)
                    }
                }
                .padding(10)
                .background(CalmPalette.mist.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if viewModel.isCreatingProject {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("New project name", text: $viewModel.newProjectName)
                        .textFieldStyle(.roundedBorder)
                    Picker("Usual category", selection: $viewModel.newProjectCategoryID) {
                        ForEach(viewModel.categories.filter { $0.id != CategoryID.inactive.rawValue }) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    HStack {
                        Button("Cancel") {
                            viewModel.cancelProjectCreation()
                        }
                        Spacer()
                        Button("Create and use") {
                            viewModel.createProjectAndUse(segmentID: segment.id)
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
            InspectorRow(label: "Category", value: viewModel.displayName(for: segment.categoryID))
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
            set: { viewModel.editSegmentCategory(segmentID: segment.id, categoryID: $0) }
        )
    }

    private func contextBinding(for segment: ActivitySegment) -> Binding<String> {
        Binding(
            get: { segment.contextID?.uuidString ?? "" },
            set: { viewModel.editSegmentContext(segmentID: segment.id, contextID: UUID(uuidString: $0)) }
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

#if DEBUG
#Preview("Today") {
    TodayView(viewModel: PreviewFactory.todayViewModel())
        .frame(width: 1_000, height: 680)
}

#Preview("Timeline Segment Row") {
    TimelineSegmentRow(
        viewModel: PreviewFactory.todayViewModel(),
        segment: PreviewFactory.segment(),
        isSelected: true,
        onSelect: {}
    )
    .padding()
    .frame(width: 680)
}

#Preview("Segment Inspector") {
    SegmentInspector(viewModel: PreviewFactory.todayViewModel(), segment: PreviewFactory.segment())
        .frame(width: 360, height: 620)
}

#Preview("Inspector Row") {
    InspectorRow(label: "Window", value: "Daily Replica - Strict MVVM-C Refactor")
        .padding()
        .frame(width: 320)
}
#endif
