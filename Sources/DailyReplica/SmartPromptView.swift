import DailyReplicaCore
import SwiftUI

struct SmartPromptView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow
    let prompt: SmartPrompt
    @State private var selectedCategoryID = CategoryID.work.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: prompt.kind == .unclassifiedActivity ? "tag.fill" : "arrow.triangle.branch")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(prompt.kind == .unclassifiedActivity ? CalmPalette.persimmon : CalmPalette.cypress)
                    .frame(width: 36, height: 36)
                    .background((prompt.kind == .unclassifiedActivity ? CalmPalette.persimmon : CalmPalette.cypress).opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(prompt.title)
                        .font(.headline)
                    Text(prompt.appName ?? prompt.urlHost ?? "Current activity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(prompt.message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if prompt.kind == .unclassifiedActivity {
                HStack {
                    Text("Put future time in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Category", selection: $selectedCategoryID) {
                        ForEach(model.categories.filter { $0.id != CategoryID.inactive.rawValue }) { category in
                            Text(category.name).tag(category.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                .padding(10)
                .background(CalmPalette.mist.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack {
                Button("Later") {
                    model.dismissPrompt()
                }
                Spacer()
                if prompt.kind == .unclassifiedActivity {
                    Button("Remember this choice") {
                        model.createRule(from: prompt, categoryID: selectedCategoryID)
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Review today") {
                        model.dismissPrompt()
                        NSApp.activate()
                        openWindow(id: "today")
                    }
                    Button("Keep context") {
                        model.dismissPrompt()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(18)
        .background(CalmPalette.porcelain.opacity(0.65))
        .onAppear {
            selectedCategoryID = prompt.suggestedCategoryID ?? CategoryID.work.rawValue
        }
    }
}
