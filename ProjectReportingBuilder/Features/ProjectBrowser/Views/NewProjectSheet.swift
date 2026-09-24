import SwiftUI

struct NewProjectSheet: View {
    @Bindable var viewModel: ProjectBrowserViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var codeName = ""
    @State private var lineOfBusiness = ""
    @State private var status: ReportStatus = .draft
    
    private var isValid: Bool {
        !codeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !lineOfBusiness.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("New Project").font(.title2)
            Form {
                TextField("Project Code Name", text: $codeName)
                    .accessibilityIdentifier("newProjectCodeName")
                TextField("Line of Business", text: $lineOfBusiness)
                    .accessibilityIdentifier("newProjectLineOfBusiness")
                Picker("Status", selection: $status) {
                    ForEach(ReportStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
            }
            if let message = viewModel.actionErrorMessage {
                Text(message).foregroundStyle(.red)
            }
            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(viewModel.isSaving)
                Spacer()
                if viewModel.isSaving { ProgressView().controlSize(.small) }
                Button("Create") {
                    Task {
                        let created = await viewModel.createProject(
                            codeName: codeName, lineOfBusiness: lineOfBusiness, status: status)
                        if created { dismiss() }
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid || viewModel.isSaving)
            }
        }
        .padding(24)
        .frame(width: 420)
        .interactiveDismissDisabled(viewModel.isSaving)
    }
}

#Preview {
    NewProjectSheet(
        viewModel: ProjectBrowserViewModel(repository: InMemoryProjectRepository())
    )
}
