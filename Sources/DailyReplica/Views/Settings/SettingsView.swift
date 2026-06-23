import DailyReplicaCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var jsonExportDocument = TextExportDocument()
    @State private var csvExportDocument = TextExportDocument()
    @State private var isExportingJSON = false
    @State private var isExportingCSV = false
    @State private var isConfirmingActivityClear = false
    @State private var isConfirmingFullReset = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                selectedPane
                    .padding(24)
            }
            .background(CalmPalette.porcelain.opacity(0.42))
        }
        .fileExporter(
            isPresented: $isExportingJSON,
            document: jsonExportDocument,
            contentType: .json,
            defaultFilename: "daily-replica-export"
        ) { _ in }
        .fileExporter(
            isPresented: $isExportingCSV,
            document: csvExportDocument,
            contentType: .dailyReplicaCSV,
            defaultFilename: "daily-replica-segments"
        ) { _ in }
        .confirmationDialog("Clear activity history?", isPresented: $isConfirmingActivityClear) {
            Button("Clear activity history", role: .destructive) {
                viewModel.clearActivityData()
            }
        } message: {
            Text("This removes tracked segments and project sessions. Categories, projects, and rules stay in place.")
        }
        .confirmationDialog("Reset all local data?", isPresented: $isConfirmingFullReset) {
            Button("Reset all local data", role: .destructive) {
                viewModel.resetAllData()
            }
        } message: {
            Text("This removes tracked activity, project sessions, custom projects, and rules stored on this Mac.")
        }
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Settings")
                        .font(.title2.bold())
                    Text("Shape how the day is interpreted.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 10)

                ForEach(SettingsSection.allCases) { section in
                    Button {
                        viewModel.selectedSection = section
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: section.systemImage)
                                .frame(width: 18)
                                .foregroundStyle(viewModel.selectedSection == section ? CalmPalette.cypress : .secondary)
                            Text(section.title)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(viewModel.selectedSection == section ? CalmPalette.cypress.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(18)
        }
        .frame(width: 210)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var selectedPane: some View {
        switch viewModel.selectedSection {
        case .categories:
            categoriesPane
        case .contexts:
            contextsPane
        case .rules:
            rulesPane
        case .permissions:
            permissionsPane
        case .updates:
            updatesPane
        }
    }

    private var categoriesPane: some View {
        PreferencePane(title: "Categories", subtitle: "Categories are simple labels like Work, Games, Reading, or Calls.") {
            CreatePanel(
                title: "Create new category",
                subtitle: "Add the words you naturally use for your day."
            ) {
                HStack(spacing: 10) {
                    TextField("Example: Reading", text: $viewModel.categoryName)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        viewModel.createCategory()
                    } label: {
                        Label("Create category", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CalmPalette.cypress)
                }
            }

            JournalSectionHeader(title: "Existing categories", detail: "\(viewModel.categories.count)")
            VStack(spacing: 8) {
                ForEach(viewModel.categories) { category in
                    PreferenceRow(
                        icon: "circle.fill",
                        tint: CalmPalette.categoryColor(category.id),
                        title: category.name,
                        subtitle: category.isBuiltIn ? "Built in" : category.id
                    )
                }
            }
        }
    }

    private var contextsPane: some View {
        PreferencePane(title: "Projects", subtitle: "Projects answer the question: what am I working on right now?") {
            CreatePanel(
                title: "Create new project",
                subtitle: "Examples: Client website, University paper, House admin."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Project name", text: $viewModel.contextName)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Picker("Usual category", selection: $viewModel.contextCategoryID) {
                            ForEach(viewModel.assignableCategories) { category in
                                Text(category.name).tag(category.id)
                            }
                        }
                        .frame(width: 220)
                        Button {
                            viewModel.createContext()
                        } label: {
                            Label("Create project", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CalmPalette.cypress)
                    }
                }
            }

            JournalSectionHeader(title: "Your projects", detail: "\(viewModel.contexts.count)")
            VStack(spacing: 8) {
                ForEach(viewModel.contexts) { context in
                    HStack {
                        PreferenceRow(
                            icon: "folder.fill",
                            tint: CalmPalette.categoryColor(context.defaultCategoryID ?? CategoryID.unclassified.rawValue),
                            title: context.name,
                            subtitle: context.defaultCategoryID.map(viewModel.displayName) ?? "No default category"
                        )
                        Spacer()
                        Button("Work on this") {
                            viewModel.setCurrentContext(id: context.id)
                        }
                        Button("Archive") {
                            viewModel.archiveContext(id: context.id)
                        }
                    }
                    .padding(.trailing, 10)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
            }
        }
    }

    private var rulesPane: some View {
        PreferencePane(title: "Auto-sort rules", subtitle: "Rules teach Daily Replica how to sort apps and websites for next time.") {
            CreatePanel(
                title: "Create new auto-sort rule",
                subtitle: "Use this when an app or website keeps showing up as unsorted."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Picker("Sort by", selection: $viewModel.ruleKind) {
                            Text("App").tag(ClassificationRuleKind.appBundleID)
                            Text("Chrome website").tag(ClassificationRuleKind.chromeHost)
                        }
                        .frame(width: 170)

                        TextField(viewModel.ruleKind == .appBundleID ? "Example: com.apple.dt.Xcode" : "Example: github.com", text: $viewModel.rulePattern)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Picker("Put it in", selection: $viewModel.ruleCategoryID) {
                            ForEach(viewModel.assignableCategories) { category in
                                Text(category.name).tag(category.id)
                            }
                        }
                        .frame(width: 220)

                        Button {
                            viewModel.createRule()
                        } label: {
                            Label("Create rule", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CalmPalette.cypress)
                    }

                    Text(viewModel.ruleKind == .appBundleID ? "Tip: app rules use bundle IDs, such as com.google.Chrome." : "Tip: website rules use the domain, such as github.com.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !viewModel.ruleSuggestions.isEmpty {
                JournalSectionHeader(title: "Suggested rules", detail: "\(viewModel.ruleSuggestions.count)")
                VStack(spacing: 8) {
                    ForEach(viewModel.ruleSuggestions) { suggestion in
                        HStack {
                            PreferenceRow(
                                icon: suggestion.kind == .appBundleID ? "app.fill" : "globe",
                                tint: CalmPalette.categoryColor(suggestion.suggestedCategoryID ?? CategoryID.unclassified.rawValue),
                                title: suggestion.title,
                                subtitle: "\(suggestion.subtitle) · \(suggestion.segmentCount) corrections · \(DurationFormatter.format(suggestion.duration))"
                            )
                            Spacer()
                            Button {
                                viewModel.acceptRuleSuggestion(suggestion)
                            } label: {
                                Label("Add rule", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(CalmPalette.cypress)
                        }
                        .padding(.trailing, 10)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
            }

            if !viewModel.unclassifiedCandidates.isEmpty {
                JournalSectionHeader(title: "Unsorted today", detail: "\(viewModel.unclassifiedCandidates.count)")
                HStack {
                    Picker("Classify as", selection: $viewModel.bulkRuleCategoryID) {
                        ForEach(viewModel.assignableCategories) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    .frame(width: 240)
                    Spacer()
                }
                VStack(spacing: 8) {
                    ForEach(viewModel.unclassifiedCandidates) { candidate in
                        HStack {
                            PreferenceRow(
                                icon: candidate.kind == .appBundleID ? "app.fill" : "globe",
                                tint: CalmPalette.categoryColor(viewModel.bulkRuleCategoryID),
                                title: candidate.title,
                                subtitle: "\(candidate.subtitle) · \(candidate.segmentCount) entries · \(DurationFormatter.format(candidate.duration))"
                            )
                            Spacer()
                            Button {
                                viewModel.classifyUncategorized(candidate)
                            } label: {
                                Label("Classify", systemImage: "tag.fill")
                            }
                        }
                        .padding(.trailing, 10)
                        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
            }

            JournalSectionHeader(title: "Existing rules", detail: "\(viewModel.rules.count)")
            VStack(spacing: 8) {
                ForEach(viewModel.rules) { rule in
                    HStack {
                        PreferenceRow(
                            icon: rule.kind == .appBundleID ? "app.fill" : "globe",
                            tint: CalmPalette.categoryColor(rule.categoryID),
                            title: rule.pattern,
                            subtitle: "\(rule.kind == .appBundleID ? "App" : "Chrome website") goes to \(viewModel.displayName(for: rule.categoryID))"
                        )
                        Spacer()
                        Picker("Category", selection: ruleCategoryBinding(for: rule)) {
                            ForEach(viewModel.assignableCategories) { category in
                                Text(category.name).tag(category.id)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                        Button("Delete") {
                            viewModel.deleteRule(id: rule.id)
                        }
                    }
                    .padding(.trailing, 10)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
            }
        }
    }

    private func ruleCategoryBinding(for rule: ClassificationRule) -> Binding<String> {
        Binding(
            get: { rule.categoryID },
            set: { viewModel.updateRuleCategory(id: rule.id, categoryID: $0) }
        )
    }

    private var permissionsPane: some View {
        PreferencePane(title: "Permissions", subtitle: "Local-only access that makes the journal more precise.") {
            VStack(spacing: 10) {
                PreferenceRow(
                    icon: viewModel.accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    tint: viewModel.accessibilityTrusted ? CalmPalette.cypress : CalmPalette.persimmon,
                    title: viewModel.accessibilityTrusted ? "Window titles enabled" : "Window titles disabled",
                    subtitle: "Accessibility lets Daily Replica read focused window titles. Without it, app-level tracking still works."
                )

                HStack {
                    PreferenceRow(
                        icon: "globe",
                        tint: CalmPalette.signalBlue,
                        title: "Chrome URLs",
                        subtitle: "Automation is requested only when Chrome tab URLs are queried. If denied, website detail stays blank."
                    )
                    Spacer()
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }

            HStack {
                Button("Request Accessibility permission") {
                    viewModel.requestAccessibilityPermission()
                }
                .buttonStyle(.borderedProminent)
                .tint(CalmPalette.cypress)
                Spacer()
            }

            CreatePanel(
                title: "Local data",
                subtitle: "Export or remove data stored by this copy of Daily Replica."
            ) {
                HStack(spacing: 10) {
                    Button {
                        if let text = viewModel.exportJSONText() {
                            jsonExportDocument = TextExportDocument(text: text)
                            isExportingJSON = true
                        }
                    } label: {
                        Label("Export JSON", systemImage: "doc.badge.arrow.up")
                    }

                    Button {
                        if let text = viewModel.exportSegmentsCSVText() {
                            csvExportDocument = TextExportDocument(text: text)
                            isExportingCSV = true
                        }
                    } label: {
                        Label("Export CSV", systemImage: "tablecells")
                    }

                    Spacer()

                    Button(role: .destructive) {
                        isConfirmingActivityClear = true
                    } label: {
                        Label("Clear activity", systemImage: "clock.badge.xmark")
                    }

                    Button(role: .destructive) {
                        isConfirmingFullReset = true
                    } label: {
                        Label("Reset all", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var updatesPane: some View {
        PreferencePane(title: "Updates", subtitle: "Signed releases are checked through Sparkle.") {
            VStack(spacing: 10) {
                PreferenceRow(
                    icon: viewModel.updatesConfigured ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                    tint: viewModel.updatesConfigured ? CalmPalette.cypress : CalmPalette.persimmon,
                    title: viewModel.updatesConfigured ? "Sparkle is configured" : "Sparkle is unavailable",
                    subtitle: viewModel.updateFeedURL?.absoluteString ?? "No appcast feed is configured for this build."
                )
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Automatic update checks", isOn: automaticUpdateChecksBinding)

                    Picker("Check interval", selection: updateIntervalBinding) {
                        ForEach(updateIntervalOptions, id: \.seconds) { option in
                            Text(option.title).tag(option.seconds)
                        }
                    }
                    .disabled(!viewModel.automaticallyChecksForUpdates)

                    Toggle("Download updates in the background", isOn: automaticDownloadBinding)
                        .disabled(!viewModel.allowsAutomaticUpdates)

                    HStack {
                        Button {
                            viewModel.checkForUpdates()
                        } label: {
                            Label("Check for Updates...", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(!viewModel.canCheckForUpdates)

                        Spacer()

                        Text(appVersionText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .disabled(!viewModel.updatesConfigured)
            }
        }
    }

    private var automaticUpdateChecksBinding: Binding<Bool> {
        Binding(
            get: { viewModel.automaticallyChecksForUpdates },
            set: { viewModel.setAutomaticallyChecksForUpdates($0) }
        )
    }

    private var automaticDownloadBinding: Binding<Bool> {
        Binding(
            get: { viewModel.automaticallyDownloadsUpdates },
            set: { viewModel.setAutomaticallyDownloadsUpdates($0) }
        )
    }

    private var updateIntervalBinding: Binding<TimeInterval> {
        Binding(
            get: { nearestUpdateInterval(to: viewModel.updateCheckInterval) },
            set: { viewModel.setUpdateCheckInterval($0) }
        )
    }

    private var updateIntervalOptions: [(title: String, seconds: TimeInterval)] {
        [
            ("Every 6 hours", 21_600),
            ("Every 12 hours", 43_200),
            ("Daily", 86_400),
            ("Weekly", 604_800)
        ]
    }

    private func nearestUpdateInterval(to interval: TimeInterval) -> TimeInterval {
        updateIntervalOptions.min { abs($0.seconds - interval) < abs($1.seconds - interval) }?.seconds ?? 86_400
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "Version \(version) (\(build))"
    }

}

private struct TextExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .dailyReplicaCSV, .plainText] }
    static var writableContentTypes: [UTType] { readableContentTypes }
    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        text = ""
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

private extension UTType {
    static var dailyReplicaCSV: UTType {
        UTType(filenameExtension: "csv") ?? .plainText
    }
}

private struct PreferencePane<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CreatePanel<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(CalmPalette.cypress)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .journalSurface(padding: 16)
    }
}

private struct PreferenceRow: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
    }
}

#if DEBUG
#Preview("Settings Categories") {
    SettingsView(viewModel: PreviewFactory.settingsViewModel(section: .categories))
        .frame(width: 820, height: 620)
}

#Preview("Settings Rules") {
    SettingsView(viewModel: PreviewFactory.settingsViewModel(section: .rules))
        .frame(width: 820, height: 620)
}

#Preview("Settings Updates") {
    SettingsView(viewModel: PreviewFactory.settingsViewModel(section: .updates))
        .frame(width: 820, height: 620)
}

#Preview("Preference Pane") {
    PreferencePane(title: "Categories", subtitle: "Labels used to organize your day.") {
        PreferenceRow(
            icon: "tag.fill",
            tint: CalmPalette.cypress,
            title: "Work",
            subtitle: "Built in"
        )
    }
    .padding()
    .frame(width: 480)
}

#Preview("Create Panel") {
    CreatePanel(title: "Create project", subtitle: "Add the context you are working on.") {
        TextField("Project name", text: .constant("Daily Replica"))
            .textFieldStyle(.roundedBorder)
    }
    .padding()
    .frame(width: 480)
}

#Preview("Preference Row") {
    PreferenceRow(
        icon: "folder.fill",
        tint: CalmPalette.signalBlue,
        title: "Daily Replica",
        subtitle: "Defaults to Work"
    )
    .padding()
    .frame(width: 420)
}
#endif
