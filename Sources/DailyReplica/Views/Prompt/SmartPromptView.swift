import DailyReplicaCore
import SwiftUI

struct SmartPromptView: View {
    @ObservedObject var viewModel: SmartPromptViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: viewModel.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(CalmPalette.categoryColor(viewModel.iconCategoryID))
                    .frame(width: 36, height: 36)
                    .background(CalmPalette.categoryColor(viewModel.iconCategoryID).opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.title)
                        .font(.headline)
                    Text(viewModel.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Text(viewModel.message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.isUnclassifiedActivity {
                HStack {
                    Text("Put future time in")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Category", selection: $viewModel.selectedCategoryID) {
                        ForEach(viewModel.assignableCategories) { category in
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
                    viewModel.dismiss()
                }
                Spacer()
                if viewModel.isUnclassifiedActivity {
                    Button("Remember this choice") {
                        viewModel.rememberChoice()
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Review today") {
                        viewModel.reviewToday()
                    }
                    Button("Keep context") {
                        viewModel.keepContext()
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(18)
        .background(CalmPalette.porcelain.opacity(0.65))
    }
}

#if DEBUG
#Preview("Smart Prompt") {
    SmartPromptView(viewModel: PreviewFactory.smartPromptViewModel())
        .frame(width: 380)
}

#Preview("Context Prompt") {
    SmartPromptView(viewModel: PreviewFactory.smartPromptViewModel(kind: .categoryMismatch))
        .frame(width: 380)
}
#endif
