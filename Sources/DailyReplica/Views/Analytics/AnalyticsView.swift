import Charts
import DailyReplicaCore
import Foundation
import SwiftUI

struct AnalyticsView: View {
    @ObservedObject var viewModel: AnalyticsViewModel

    private let calendar = Calendar.dailyReplica
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                periodControls
                filters

                if viewModel.report.hasData {
                    trendCharts
                    calendarHeatmap
                    breakdownSection
                    drilldownDetails
                } else {
                    EmptyJournalState(
                        title: "No tracked time yet",
                        message: "Track a little activity and come back to explore analytics.",
                        systemImage: "chart.xyaxis.line"
                    )
                }
            }
            .padding(22)
        }
        .onAppear {
            viewModel.reload()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Analytics")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text(viewModel.dateRangeLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if viewModel.isShowingDrilldown && (calendar.isDateInToday(viewModel.selectedDrilldownDate ?? .distantPast)) {
                    Button {
                        viewModel.openToday()
                    } label: {
                        Label("Back to today", systemImage: "arrow.uturn.left")
                    }
                    .buttonStyle(.bordered)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                MetricTile(title: "Tracked", value: DurationFormatter.format(viewModel.report.totalDuration), tint: CalmPalette.cypress, symbol: "clock")
                MetricTile(title: "Active", value: DurationFormatter.format(viewModel.report.activeDuration), tint: CalmPalette.signalBlue, symbol: "bolt.fill")
                MetricTile(title: "Inactive", value: DurationFormatter.format(viewModel.report.inactiveDuration), tint: CalmPalette.graphite, symbol: "moon.zzz.fill")
                MetricTile(title: "Unsorted", value: DurationFormatter.format(viewModel.report.unclassifiedDuration), tint: CalmPalette.persimmon, symbol: "tag.slash.fill")
            }
        }
        .journalSurface(padding: 18)
    }

    private var periodControls: some View {
        HStack(spacing: 12) {
            Picker("Period", selection: periodBinding) {
                ForEach(AnalyticsPeriod.allCases) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 300)

            Spacer()

            HStack(spacing: 8) {
                Button {
                    viewModel.movePeriod(by: -1)
                } label: {
                    Label("Previous", systemImage: "chevron.left")
                }
                .disabled(!viewModel.canMoveBackward)

                Button("Today") {
                    viewModel.jumpToToday()
                }

                Button {
                    viewModel.movePeriod(by: 1)
                } label: {
                    Label("Next", systemImage: "chevron.right")
                }
                .disabled(!viewModel.canMoveForward)
            }
            .buttonStyle(.bordered)
        }
        .journalSurface(padding: 12)
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                JournalSectionHeader(title: "Filters", detail: "Narrow the report")
                Spacer()
                if viewModel.selectedFilter.hasSelection {
                    Button("Clear") {
                        viewModel.clearFilter()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CalmPalette.cypress)
                }
            }

            HStack(spacing: 10) {
                filterMenu(
                    "Category",
                    selection: categoryFilterSelection,
                    items: viewModel.categories.map { ($0.id, $0.name) },
                    onSelect: { value in
                        viewModel.setCategoryFilter(value == "all" ? nil : value)
                    }
                )

                filterMenu(
                    "Project",
                    selection: contextFilterSelection,
                    items: viewModel.contexts.map { ($0.id.uuidString, $0.name) },
                    onSelect: { value in
                        viewModel.setContextFilter(UUID(uuidString: value))
                    }
                )

                filterMenu(
                    "App",
                    selection: appFilterSelection,
                    items: viewModel.appFilterOptions.map { ($0.id, $0.title) },
                    onSelect: { value in
                        viewModel.setAppFilter(value == "all" ? nil : value)
                    }
                )

                filterMenu(
                    "Website",
                    selection: websiteFilterSelection,
                    items: viewModel.websiteFilterOptions.map { ($0.id, $0.title) },
                    onSelect: { value in
                        viewModel.setWebsiteFilter(value == "all" ? nil : value)
                    }
                )
            }
        }
        .journalSurface(padding: 12)
    }

    private var trendCharts: some View {
        VStack(alignment: .leading, spacing: 12) {
            JournalSectionHeader(title: "Trends", detail: "Daily trend in selected interval")

            VStack(spacing: 12) {
                HStack {
                    Text("Active • Inactive • Unsorted")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(viewModel.drilldownDateTitle)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Chart(stackedTrendData, id: \.id) { entry in
                    BarMark(
                        x: .value("Date", entry.date, unit: .day),
                        yStart: .value("Start", entry.base),
                        yEnd: .value("End", entry.limit),
                        width: .fixed(14)
                    )
                    .foregroundStyle(entry.type == .active ? CalmPalette.signalBlue : entry.type == .inactive ? CalmPalette.graphite : CalmPalette.persimmon)
                    .cornerRadius(3)
                }
                .frame(height: 190)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    if viewModel.selectedPeriod == .day {
                        AxisMarks(values: .automatic(desiredCount: 1))
                    } else {
                        AxisMarks(values: .automatic(desiredCount: 7))
                    }
                }

                HStack {
                    ForEach([
                        ("Active", CalmPalette.signalBlue),
                        ("Inactive", CalmPalette.graphite),
                        ("Unsorted", CalmPalette.persimmon)
                    ], id: \.0) { item in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(item.1)
                                .frame(width: 8, height: 8)
                            Text(item.0)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
            .journalSurface()

            VStack(alignment: .leading, spacing: 8) {
                JournalSectionHeader(title: "Unsorted trend", detail: "Classification debt")
                Chart {
                    ForEach(viewModel.report.dailyPoints) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Unsorted", point.unclassifiedDuration)
                        )
                        .lineStyle(.init(lineWidth: 3, lineCap: .round))
                        .foregroundStyle(CalmPalette.persimmon)

                        AreaMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Unsorted", point.unclassifiedDuration)
                        )
                        .foregroundStyle(CalmPalette.persimmon.opacity(0.22))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 120)
            }
            .journalSurface()
        }
    }

    private var calendarHeatmap: some View {
        VStack(alignment: .leading, spacing: 12) {
            JournalSectionHeader(title: "Calendar heatmap", detail: "Click any day to drill into that day")
            calendarGrid
        }
        .journalSurface()
    }

    private var calendarGrid: some View {
        let rows = heatmapRows
        let maxTotal = max(1, viewModel.report.calendarDays.map(\.totalDuration).max() ?? 1)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                ForEach(Array(calendar.shortWeekdaySymbols.enumerated()), id: \.offset) { _, weekday in
                    Text(weekday.prefix(3))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: 6) {
                ForEach(rows.indices, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(rows[row].indices, id: \.self) { column in
                            if let day = rows[row][column] {
                                let intensity = min(1, day.totalDuration / maxTotal)
                                Button {
                                    viewModel.selectDrilldownDate(day.date)
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(dateFormatter.string(from: day.date))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(DurationFormatter.format(day.totalDuration))
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                        if day.unclassifiedDuration > 60 {
                                            Circle()
                                                .fill(CalmPalette.persimmon)
                                                .frame(width: 5, height: 5)
                                        }
                                    }
                                    .frame(width: 68, height: 60)
                                    .background(
                                        CalmPalette.signalBlue.opacity(0.18 + 0.78 * intensity),
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                                    .overlay {
                                        if isSameDay(day.date, viewModel.selectedDrilldownDate) {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(CalmPalette.cypress, lineWidth: 2)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.clear)
                                    .frame(width: 68, height: 60)
                            }
                        }
                    }
                }
            }
        }
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            JournalSectionHeader(title: "Breakdowns", detail: "Tap an item to filter")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                categoryBreakdown
                projectBreakdown
                appBreakdown
                websiteBreakdown
            }
        }
    }

    private var categoryBreakdown: some View {
        breakdownPanel(
            title: "Categories",
            items: viewModel.report.categoryItems,
            tint: CalmPalette.cypress,
            titleForItem: { viewModel.selectedCategoryDisplayName(for: $0.id) }
        ) { item in
            if viewModel.selectedFilter.categoryID == item.id {
                viewModel.clearFilter()
            } else {
                viewModel.setCategoryFilter(item.id)
            }
        }
    }

    private var projectBreakdown: some View {
        breakdownPanel(
            title: "Projects",
            items: viewModel.report.projectItems,
            tint: CalmPalette.iris,
            titleForItem: \.title
        ) { item in
            if viewModel.selectedFilter.contextID == UUID(uuidString: item.id) {
                viewModel.clearFilter()
            } else {
                viewModel.setContextFilter(UUID(uuidString: item.id))
            }
        }
    }

    private var appBreakdown: some View {
        breakdownPanel(
            title: "Apps",
            items: viewModel.report.appItems,
            tint: CalmPalette.signalBlue,
            titleForItem: \.title
        ) { item in
            if viewModel.selectedFilter.appIdentifier == item.id {
                viewModel.clearFilter()
            } else {
                viewModel.setAppFilter(item.id)
            }
        }
    }

    private var websiteBreakdown: some View {
        breakdownPanel(
            title: "Websites",
            items: viewModel.report.websiteItems,
            tint: CalmPalette.rose,
            titleForItem: \.title
        ) { item in
            if viewModel.selectedFilter.websiteHost == item.id {
                viewModel.clearFilter()
            } else {
                viewModel.setWebsiteFilter(item.id)
            }
        }
    }

    private func breakdownPanel(
        title: String,
        items: [AnalyticsBreakdown],
        tint: Color,
        titleForItem: @escaping (AnalyticsBreakdown) -> String,
        onSelect: @escaping (AnalyticsBreakdown) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            if items.isEmpty {
                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let chartItems = Array(items.prefix(6))
                let maxDuration = max(1, chartItems.map(\.duration).max() ?? 1)
                Chart(chartItems, id: \.id) { item in
                    BarMark(
                        x: .value("Duration", item.duration / 3600),
                        y: .value("Item", titleForItem(item))
                    )
                    .foregroundStyle(tint.gradient)
                }
                .chartXScale(domain: 0 ... maxDuration / 3600)
                .frame(height: 112)

                VStack(spacing: 4) {
                    ForEach(chartItems) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            HStack(spacing: 8) {
                                Text(titleForItem(item))
                                    .lineLimit(1)
                                Spacer()
                                Text(DurationFormatter.format(item.duration))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .font(.caption)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .journalSurface(padding: 12)
    }

    private var drilldownDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                JournalSectionHeader(title: viewModel.drilldownDateTitle, detail: "Selected interval details")
                Spacer()
                if viewModel.isShowingDrilldown {
                    Button("Clear") {
                        viewModel.clearDrilldown()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CalmPalette.cypress)
                }
            }

            if viewModel.isShowingDrilldown {
                VStack(alignment: .leading, spacing: 6) {
                    if let top = viewModel.report.categoryItems.first {
                        Text("Top category: \(viewModel.selectedCategoryDisplayName(for: top.id))")
                    }
                    if let top = viewModel.report.projectItems.first {
                        Text("Top project: \(top.title)")
                    }
                    if let top = viewModel.report.appItems.first {
                        Text("Top app: \(top.title)")
                    }
                    if let top = viewModel.report.websiteItems.first {
                        Text("Top website: \(top.title)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if viewModel.selectedDrilldownDate == nil {
                Text("Showing selected period totals. Pick a day in the calendar to drill into a day.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .journalSurface(padding: 14)
    }

    private var periodBinding: Binding<AnalyticsPeriod> {
        Binding(
            get: { viewModel.selectedPeriod },
            set: { viewModel.setPeriod($0) }
        )
    }

    private var categoryFilterSelection: String {
        viewModel.selectedFilter.categoryID ?? "all"
    }

    private var contextFilterSelection: String {
        viewModel.selectedFilter.contextID?.uuidString ?? "all"
    }

    private var appFilterSelection: String {
        viewModel.selectedFilter.appIdentifier ?? "all"
    }

    private var websiteFilterSelection: String {
        viewModel.selectedFilter.websiteHost ?? "all"
    }

    private var stackedTrendData: [TrendStackEntry] {
        viewModel.report.dailyPoints.flatMap { point in
            let inactiveStart = point.activeDuration
            let unsortedStart = point.activeDuration + point.inactiveDuration
            return [
                TrendStackEntry(id: "\(point.date.timeIntervalSinceReferenceDate)-active", date: point.date, type: .active, base: 0, limit: point.activeDuration),
                TrendStackEntry(id: "\(point.date.timeIntervalSinceReferenceDate)-inactive", date: point.date, type: .inactive, base: inactiveStart, limit: inactiveStart + point.inactiveDuration),
                TrendStackEntry(id: "\(point.date.timeIntervalSinceReferenceDate)-unsorted", date: point.date, type: .unsorted, base: unsortedStart, limit: unsortedStart + point.unclassifiedDuration)
            ]
        }
    }

    private var heatmapRows: [[AnalyticsCalendarDay?]] {
        let days = viewModel.report.calendarDays.sorted { $0.date < $1.date }
        guard let first = days.first?.date else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: first)
        let alignment = (firstWeekday - calendar.firstWeekday + 7) % 7
        let totalColumns = 7

        var rows: [[AnalyticsCalendarDay?]] = []
        var currentRow: [AnalyticsCalendarDay?] = Array(repeating: nil, count: totalColumns)
        var cursor = 0

        while cursor < alignment {
            currentRow[cursor] = nil
            cursor += 1
        }

        for day in days {
            if cursor == totalColumns {
                rows.append(currentRow)
                currentRow = Array(repeating: nil, count: totalColumns)
                cursor = 0
            }
            currentRow[cursor] = day
            cursor += 1
        }

        if currentRow.contains(where: { $0 != nil }) {
            rows.append(currentRow)
        }

        return rows
    }

    private func isSameDay(_ lhs: Date, _ rhs: Date?) -> Bool {
        guard let rhs else {
            return false
        }
        return calendar.isDate(lhs, inSameDayAs: rhs)
    }

    private func filterMenu(
        _ title: String,
        selection: String,
        items: [(String, String)],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            Button("All") { onSelect("all") }
            Divider()
            ForEach(items, id: \.0) { item in
                Button(item.1) { onSelect(item.0) }
            }
        } label: {
            Text("\(title): \(label(for: selection, items: items))")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(CalmPalette.mist.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .buttonStyle(.borderless)
    }

    private func label(for value: String, items: [(String, String)]) -> String {
        if value == "all" {
            return "All"
        }
        return items.first(where: { $0.0 == value })?.1 ?? value
    }
}

private struct TrendStackEntry: Identifiable {
    enum TrendType {
        case active
        case inactive
        case unsorted
    }

    let id: String
    let date: Date
    let type: TrendType
    let base: TimeInterval
    let limit: TimeInterval
}

#if DEBUG
#Preview("Analytics") {
    AnalyticsView(viewModel: PreviewFactory.analyticsViewModel())
        .frame(width: 1_220, height: 840)
}
#endif
