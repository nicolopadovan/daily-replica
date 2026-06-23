import DailyReplicaCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedSection = SettingsSection.categories
    @State private var categoryName = ""
    @State private var contextName = ""
    @State private var contextCategoryID = CategoryID.work.rawValue
    @State private var ruleKind = ClassificationRuleKind.appBundleID
    @State private var rulePattern = ""
    @State private var ruleCategoryID = CategoryID.work.rawValue

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
    }

    private var sidebar: some View {
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
                    selectedSection = section
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: section.systemImage)
                            .frame(width: 18)
                            .foregroundStyle(selectedSection == section ? CalmPalette.cypress : .secondary)
                        Text(section.title)
                        Spacer()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(selectedSection == section ? CalmPalette.cypress.opacity(0.11) : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
    private var selectedPane: some View {
        switch selectedSection {
        case .categories:
            categoriesPane
        case .contexts:
            contextsPane
        case .rules:
            rulesPane
        case .permissions:
            permissionsPane
        }
    }

    private var categoriesPane: some View {
        PreferencePane(title: "Categories", subtitle: "Categories are simple labels like Work, Games, Reading, or Calls.") {
            CreatePanel(
                title: "Create new category",
                subtitle: "Add the words you naturally use for your day."
            ) {
                HStack(spacing: 10) {
                    TextField("Example: Reading", text: $categoryName)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        model.addCategory(name: categoryName)
                        categoryName = ""
                    } label: {
                        Label("Create category", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(CalmPalette.cypress)
                }
            }

            JournalSectionHeader(title: "Existing categories", detail: "\(model.categories.count)")
            VStack(spacing: 8) {
                ForEach(model.categories) { category in
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
                    TextField("Project name", text: $contextName)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Picker("Usual category", selection: $contextCategoryID) {
                            ForEach(assignableCategories) { category in
                                Text(category.name).tag(category.id)
                            }
                        }
                        .frame(width: 220)
                        Button {
                            model.addContext(name: contextName, defaultCategoryID: contextCategoryID)
                            contextName = ""
                        } label: {
                            Label("Create project", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CalmPalette.cypress)
                    }
                }
            }

            JournalSectionHeader(title: "Your projects", detail: "\(model.contexts.count)")
            VStack(spacing: 8) {
                ForEach(model.contexts) { context in
                    HStack {
                        PreferenceRow(
                            icon: "folder.fill",
                            tint: CalmPalette.categoryColor(context.defaultCategoryID ?? CategoryID.unclassified.rawValue),
                            title: context.name,
                            subtitle: context.defaultCategoryID.map(model.displayName) ?? "No default category"
                        )
                        Spacer()
                        Button("Work on this") {
                            model.setCurrentContext(id: context.id)
                        }
                        Button("Archive") {
                            model.archiveContext(id: context.id)
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
                        Picker("Sort by", selection: $ruleKind) {
                            Text("App").tag(ClassificationRuleKind.appBundleID)
                            Text("Chrome website").tag(ClassificationRuleKind.chromeHost)
                        }
                        .frame(width: 170)

                        TextField(ruleKind == .appBundleID ? "Example: com.apple.dt.Xcode" : "Example: github.com", text: $rulePattern)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Picker("Put it in", selection: $ruleCategoryID) {
                            ForEach(assignableCategories) { category in
                                Text(category.name).tag(category.id)
                            }
                        }
                        .frame(width: 220)

                        Button {
                            model.addRule(kind: ruleKind, pattern: rulePattern, categoryID: ruleCategoryID)
                            rulePattern = ""
                        } label: {
                            Label("Create rule", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(CalmPalette.cypress)
                    }

                    Text(ruleKind == .appBundleID ? "Tip: app rules use bundle IDs, such as com.google.Chrome." : "Tip: website rules use the domain, such as github.com.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            JournalSectionHeader(title: "Existing rules", detail: "\(model.rules.count)")
            VStack(spacing: 8) {
                ForEach(model.rules) { rule in
                    HStack {
                        PreferenceRow(
                            icon: rule.kind == .appBundleID ? "app.fill" : "globe",
                            tint: CalmPalette.categoryColor(rule.categoryID),
                            title: rule.pattern,
                            subtitle: "\(rule.kind == .appBundleID ? "App" : "Chrome website") goes to \(model.displayName(for: rule.categoryID))"
                        )
                        Spacer()
                        Button("Delete") {
                            model.deleteRule(id: rule.id)
                        }
                    }
                    .padding(.trailing, 10)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
            }
        }
    }

    private var permissionsPane: some View {
        PreferencePane(title: "Permissions", subtitle: "Local-only access that makes the journal more precise.") {
            VStack(spacing: 10) {
                PreferenceRow(
                    icon: model.accessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    tint: model.accessibilityTrusted ? CalmPalette.cypress : CalmPalette.persimmon,
                    title: model.accessibilityTrusted ? "Window titles enabled" : "Window titles disabled",
                    subtitle: "Accessibility lets Daily Replica read the focused window title."
                )

                HStack {
                    PreferenceRow(
                        icon: "globe",
                        tint: CalmPalette.signalBlue,
                        title: "Chrome URLs",
                        subtitle: "macOS asks for Automation permission the first time Chrome is queried."
                    )
                    Spacer()
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            }

            Button("Request Accessibility permission") {
                model.requestAccessibilityPermission()
            }
            .buttonStyle(.borderedProminent)
            .tint(CalmPalette.cypress)
        }
    }

    private var assignableCategories: [CategoryDefinition] {
        model.categories.filter { $0.id != CategoryID.inactive.rawValue }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case categories
    case contexts
    case rules
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .categories: "Categories"
        case .contexts: "Projects"
        case .rules: "Auto-sort"
        case .permissions: "Permissions"
        }
    }

    var systemImage: String {
        switch self {
        case .categories: "square.grid.2x2.fill"
        case .contexts: "folder.fill"
        case .rules: "tag.fill"
        case .permissions: "lock.shield.fill"
        }
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
