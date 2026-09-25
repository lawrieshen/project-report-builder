import SwiftUI

struct ProjectBrowserView: View {
    @Bindable var viewModel: ProjectBrowserViewModel
    let openProject: (ProjectReport) -> Void
    let newProject: () -> Void
    var isCreatingProject = false
    let showFilters: () -> Void
    var duplicateProject: (ProjectReport) -> Void = { _ in }
    @State private var projectToDelete: ProjectReport?
    
    var body: some View {
        VStack(spacing: 0) {
            browserHeader
            if !viewModel.storageWarnings.isEmpty {
                Text("Some projects could not be loaded.\n" + viewModel.storageWarnings.joined(separator: "\n"))
                    .font(.caption).foregroundStyle(.orange).padding(AppSpacing.cardInset)
            }
            Divider()
            browserContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await viewModel.loadProjects() }
        .confirmationDialog("Delete this project?", isPresented: Binding(
            get: { projectToDelete != nil },
            set: { if !$0 { projectToDelete = nil } }
        ), titleVisibility: .visible) {
            if let project = projectToDelete {
                Button("Delete", role: .destructive) {
                    Task { await viewModel.deleteProject(project) }
                }
            }
            Button("Cancel", role: .cancel) { projectToDelete = nil }
        } message: {
            Text("This action cannot be undone.")
        }
        .alert("Unable to Complete Action", isPresented: Binding(
            get: { viewModel.actionErrorMessage != nil && !isCreatingProject },
            set: { if !$0 { viewModel.actionErrorMessage = nil } }
        )) {
            Button("OK") { viewModel.actionErrorMessage = nil }
        } message: {
            Text(viewModel.actionErrorMessage ?? "")
        }

    }
    
    @ViewBuilder
    private var browserHeader: some View {
        VStack(spacing: AppSpacing.field) {
            titleAndSearch
            ProjectFilterBar(searchText: $viewModel.searchText,
                             filter: $viewModel.filter,
                             linesOfBusiness: viewModel.linesOfBusiness,
                             showFilters: showFilters)
            .disabled(viewModel.isLoading || viewModel.isSaving)
        }
        .padding(.horizontal, AppSpacing.pageInset)
        .padding(.vertical, AppSpacing.cardInset)
        .fixedSize(horizontal: false, vertical: true)
    }
    
    @ViewBuilder
    private var browserContent: some View {
        if viewModel.isLoading {
            ProgressView("Loading projects…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let message = viewModel.errorMessage {
            ContentUnavailableView {
                Label("Unable to load projects.", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Retry") { Task { await viewModel.loadProjects() } }
            }
        } else if viewModel.visibleProjects.isEmpty {
            ProjectEmptyStateView(hasProjects: !viewModel.projects.isEmpty,
                                  searchText: viewModel.searchText,
                                  hasFilters: !viewModel.filter.isEmpty,
                                  newProject: showNewProject,
                                  clearSearch: { viewModel.searchText = "" },
                                  clearFilters: { viewModel.clearFilters() })
        } else {
            ProjectGridView(projects: viewModel.visibleProjects,
                            open: openProject,
                            delete: { projectToDelete = $0 }, duplicate: duplicateProject)
            .disabled(viewModel.isSaving)
        }
    }
    
    private func showNewProject() {
        viewModel.actionErrorMessage = nil
        newProject()
    }
    
    @ViewBuilder
    private var titleAndSearch: some View {
        HStack {
            Text("Projects").font(.largeTitle.bold())
            Spacer()
            TextField("Search projects", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
                .accessibilityLabel("Search projects")
        }
    }
}

#Preview {
    ContentView(repository: InMemoryProjectRepository())
}
