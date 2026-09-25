import SwiftUI

struct NewProjectCard: View {
    @Bindable var viewModel: ProjectBrowserViewModel
    let onDismiss: () -> Void
    let onCreated: (ProjectReport) -> Void
    @FocusState private var isCodeNameFocused: Bool
    @State private var codeName = ""
    @State private var lineOfBusiness = ""
    @State private var status: ProjectStatus = .draft
    
    private var isValid: Bool {
        !codeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !lineOfBusiness.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            cardHeader
            scrollableContent
            actionButtons
        }
        .floatingCard()
        .task { isCodeNameFocused = true }
    }
    
    @ViewBuilder
    private var cardHeader: some View {
        Text("New Project")
            .font(.title2)
    }
    
    @ViewBuilder
    private var scrollableContent: some View {
        ViewThatFits(in: .vertical) {
            formContent
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                formContent
            }
        }
    }

    @ViewBuilder
    private var formContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            projectForm
            errorMessage
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                ForEach(ProjectStatus.allCases, id: \.self) { status in
                    Text(status.displayName).tag(status)
                }
            }
        }
    }
    
    @ViewBuilder
    private var errorMessage: some View {
        if let message = viewModel.actionErrorMessage {
            Text(message)
                .floatingCardError()
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
            
            Button("Create & Open") {
                Task {
                    let created = await viewModel.createProject(
                        codeName: codeName, lineOfBusiness: lineOfBusiness, status: status)
                    if let created {
                        onCreated(created)
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
        onDismiss: {},
        onCreated: { _ in }
    )
}
