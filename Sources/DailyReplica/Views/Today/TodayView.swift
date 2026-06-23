import DailyReplicaCore
import SwiftUI

struct TodayView: View {
    @ObservedObject var viewModel: TodayViewModel

    var body: some View {
        NavigationSplitView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    journalHeader
                    dashboardPanel

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
                .frame(minWidth: 760, maxWidth: .infinity, alignment: .leading)
            }
            .background(CalmPalette.porcelain.opacity(0.55))
            .navigationSplitViewColumnWidth(min: 760, ideal: 900)
        } detail: {
            SegmentInspector(viewModel: viewModel, segment: viewModel.selectedSegment)
                .frame(maxHeight: .infinity)
                .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 380)
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
                    if viewModel.activeProjectSession != nil {
                        Text("Project time \(viewModel.activeProjectElapsed)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
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

    private var dashboardPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                JournalSectionHeader(title: "Screen Time", detail: viewModel.dashboardIntervalTitle)

                Picker("Period", selection: dashboardPeriodBinding) {
                    ForEach(DashboardPeriod.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 210)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                DashboardMetricCell(
                    title: "Tracked",
                    value: DurationFormatter.format(viewModel.dashboardSummary.totalDuration),
                    tint: CalmPalette.cypress,
                    symbol: "clock"
                )
                DashboardMetricCell(
                    title: "Focused",
                    value: DurationFormatter.format(viewModel.dashboardSummary.focusedWorkDuration),
                    tint: CalmPalette.signalBlue,
                    symbol: "scope"
                )
                DashboardMetricCell(
                    title: "Distractions",
                    value: DurationFormatter.format(viewModel.dashboardSummary.distractionDuration),
                    tint: CalmPalette.rose,
                    symbol: "exclamationmark.triangle.fill"
                )
                DashboardMetricCell(
                    title: "Unsorted",
                    value: DurationFormatter.format(viewModel.dashboardSummary.unclassifiedDuration),
                    tint: CalmPalette.persimmon,
                    symbol: "tag.slash.fill"
                )
            }

            if !viewModel.dashboardDailyTotals.isEmpty {
                DashboardDailyTotalsStrip(totals: viewModel.dashboardDailyTotals)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                DashboardRankList(
                    title: "Categories",
                    items: viewModel.dashboardCategoryItems,
                    emptyTitle: "No category time",
                    titleForItem: { viewModel.displayName(for: $0.id) },
                    tintForItem: { CalmPalette.categoryColor($0.id) }
                )
                DashboardRankList(
                    title: "Projects",
                    items: viewModel.dashboardProjectItems,
                    emptyTitle: "No project time",
                    tint: CalmPalette.cypress
                )
                DashboardRankList(
                    title: "Apps",
                    items: viewModel.dashboardAppItems,
                    emptyTitle: "No app time",
                    tint: CalmPalette.signalBlue
                )
                DashboardRankList(
                    title: "Websites",
                    items: viewModel.dashboardWebsiteItems,
                    emptyTitle: "No website time",
                    tint: CalmPalette.iris
                )
            }
        }
        .journalSurface()
    }

    private var dashboardPeriodBinding: Binding<DashboardPeriod> {
        Binding(
            get: { viewModel.dashboardPeriod },
            set: { viewModel.setDashboardPeriod($0) }
        )
    }

    private var timeline: some View {
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

private struct DashboardMetricCell: View {
    let title: String
    let value: String
    let tint: Color
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                    .lineLimit(1)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(CalmPalette.porcelain.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DashboardRankList: View {
    let title: String
    let items: [DashboardMetricItem]
    let emptyTitle: String
    var titleForItem: (DashboardMetricItem) -> String = { $0.title }
    var tintForItem: (DashboardMetricItem) -> Color

    init(
        title: String,
        items: [DashboardMetricItem],
        emptyTitle: String,
        titleForItem: @escaping (DashboardMetricItem) -> String = { $0.title },
        tintForItem: @escaping (DashboardMetricItem) -> Color
    ) {
        self.title = title
        self.items = items
        self.emptyTitle = emptyTitle
        self.titleForItem = titleForItem
        self.tintForItem = tintForItem
    }

    init(title: String, items: [DashboardMetricItem], emptyTitle: String, tint: Color) {
        self.title = title
        self.items = items
        self.emptyTitle = emptyTitle
        self.tintForItem = { _ in tint }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if items.isEmpty {
                Text(emptyTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            } else {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        DashboardRankRow(
                            title: titleForItem(item),
                            duration: item.duration,
                            maxDuration: maxDuration,
                            tint: tintForItem(item)
                        )
                    }
                }
            }
        }
    }

    private var maxDuration: TimeInterval {
        max(items.map(\.duration).max() ?? 1, 1)
    }
}

private struct DashboardRankRow: View {
    let title: String
    let duration: TimeInterval
    let maxDuration: TimeInterval
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.caption)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(DurationFormatter.format(duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(CalmPalette.mist.opacity(0.65))
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 5)
        }
    }

    private var progress: CGFloat {
        CGFloat(min(max(duration / maxDuration, 0), 1))
    }
}

private struct DashboardDailyTotalsStrip: View {
    let totals: [DashboardDailyTotal]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily totals")
                .font(.subheadline.weight(.semibold))

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(totals) { total in
                    VStack(spacing: 5) {
                        GeometryReader { proxy in
                            VStack {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(total.unclassifiedDuration > 0 ? CalmPalette.persimmon : CalmPalette.cypress)
                                    .frame(height: max(3, proxy.size.height * barProgress(for: total)))
                            }
                        }
                        .frame(height: 42)

                        Text(total.date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var maxDuration: TimeInterval {
        max(totals.map(\.totalDuration).max() ?? 1, 1)
    }

    private func barProgress(for total: DashboardDailyTotal) -> CGFloat {
        CGFloat(min(max(total.totalDuration / maxDuration, 0), 1))
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
        "\(segment.start.formatted(.dateTime.hour().minute().second())) - \(segment.end.formatted(.dateTime.hour().minute().second()))"
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
                timelineEditingControls(for: segment)
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

    private func timelineEditingControls(for segment: ActivitySegment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            JournalSectionHeader(title: "Timeline edit")

            DatePicker(
                "Split at",
                selection: $viewModel.splitTime,
                in: segment.start...segment.end,
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.compact)

            HStack(spacing: 8) {
                Button {
                    viewModel.mergeSelectedSegmentWithPrevious()
                } label: {
                    Label("Merge previous", systemImage: "arrow.left.to.line.compact")
                }
                .disabled(!viewModel.canMergeSelectedSegmentWithPrevious)

                Button {
                    viewModel.splitSelectedSegment()
                } label: {
                    Label("Split", systemImage: "scissors")
                }
                .buttonStyle(.borderedProminent)
                .tint(CalmPalette.cypress)
                .disabled(!viewModel.canSplitSelectedSegment)

                Button {
                    viewModel.mergeSelectedSegmentWithNext()
                } label: {
                    Label("Merge next", systemImage: "arrow.right.to.line.compact")
                }
                .disabled(!viewModel.canMergeSelectedSegmentWithNext)

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    viewModel.deleteSelectedSegment()
                } label: {
                    Label("Delete entry", systemImage: "trash")
                }
                .disabled(segment.state == .inactive && segment.categoryID == CategoryID.inactive.rawValue)
            }
            .font(.caption)
        }
        .journalSurface()
    }

    private func metadata(for segment: ActivitySegment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            JournalSectionHeader(title: "Details")
            InspectorRow(label: "Time", value: "\(segment.start.formatted(.dateTime.hour().minute().second())) - \(segment.end.formatted(.dateTime.hour().minute().second()))")
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
