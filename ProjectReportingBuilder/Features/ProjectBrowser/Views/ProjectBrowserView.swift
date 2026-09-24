import SwiftUI

struct ProjectBrowserView: View {
    @Bindable var viewModel: ProjectBrowserViewModel
    @Binding var showingNewProject: Bool
    @State private var projectToDelete: ProjectReport?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                browserHeader
                Divider()
                browserContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationDestination(item: $viewModel.selectedProject) { project in
                reportEditorPlaceholder(for: project)
            }
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
            get: { viewModel.actionErrorMessage != nil && !showingNewProject },
            set: { if !$0 { viewModel.actionErrorMessage = nil } }
        )) {
            Button("OK") { viewModel.actionErrorMessage = nil }
        } message: {
            Text(viewModel.actionErrorMessage ?? "")
        }
    }
    
    @ViewBuilder
    private var browserHeader: some View {
        VStack(spacing: 10) {
            titleAndSearch
            ProjectFilterBar(filter: $viewModel.filter,
                             linesOfBusiness: viewModel.linesOfBusiness)
            .disabled(viewModel.isLoading || viewModel.isSaving)
        }
        .padding(.horizontal, 16)
        .padding(.top, 36)
        .padding(.bottom, 16)
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
                            open: { viewModel.selectProject($0) },
                            delete: { projectToDelete = $0 })
            .disabled(viewModel.isSaving)
        }
    }
    
    @ViewBuilder
    private func reportEditorPlaceholder(for project: ProjectReport) -> some View {
        // The reporting workflow is implemented in a later feature.
        ContentUnavailableView {
            Label(project.codeName, systemImage: "doc.text")
        } description: {
            Text("Report Editor is not available yet.")
        }
        .navigationTitle(project.codeName)
    }

    private func showNewProject() {
        viewModel.actionErrorMessage = nil
        showingNewProject = true
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
