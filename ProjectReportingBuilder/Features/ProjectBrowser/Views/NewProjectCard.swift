import SwiftUI

struct NewProjectCard: View {
    @Bindable var viewModel: ProjectBrowserViewModel
    let onDismiss: () -> Void
    @FocusState private var isCodeNameFocused: Bool
    @State private var codeName = ""
    @State private var lineOfBusiness = ""
    @State private var status: ReportStatus = .draft
    
    private var isValid: Bool {
        !codeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !lineOfBusiness.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            cardHeader
            scrollableContent
            actionButtons
        }
        .padding(24)
        .frame(width: 420)
        .frame(maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.primary.opacity(0.08))
        }
        .task { isCodeNameFocused = true }
    }
    
    @ViewBuilder
    private var cardHeader: some View {
        Text("New Project")
            .font(.title2)
    }
    
    @ViewBuilder
    private var scrollableContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                projectForm
                errorMessage
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var projectForm: some View {
        Form {
            TextField("Project Code Name", text: $codeName)
                .accessibilityIdentifier("newProjectCodeName")
                .focused($isCodeNameFocused)
            TextField("Line of Business", text: $lineOfBusiness)
                .accessibilityIdentifier("newProjectLineOfBusiness")
            Picker("Status", selection: $status) {
                ForEach(ReportStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
        }
    }
    
    @ViewBuilder
    private var errorMessage: some View {
        if let message = viewModel.actionErrorMessage {
            Text(message)
                .foregroundStyle(.red)
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Button("Cancel") { onDismiss() }
                .keyboardShortcut(.cancelAction)
                .disabled(viewModel.isSaving)
            
            Spacer()
            
            if viewModel.isSaving {
                ProgressView()
                    .controlSize(.small)
            }
            
            Button("Create") {
                Task {
                    let created = await viewModel.createProject(
                        codeName: codeName, lineOfBusiness: lineOfBusiness, status: status)
                    if created {
                        onDismiss()
                    }
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid || viewModel.isSaving)
        }
    }
}

#Preview {
    NewProjectCard(
        viewModel: ProjectBrowserViewModel(repository: InMemoryProjectRepository()),
        onDismiss: {}
    )
}
