import Foundation
import Observation

@MainActor
@Observable
final class ProjectBrowserViewModel {
    private(set) var projects: [ProjectReport] = []
    var searchText = ""
    var filter = ProjectBrowserFilter()
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var storageWarnings: [String] = []
    var actionErrorMessage: String?
    
    private let repository: any ProjectRepository
    
    init(repository: any ProjectRepository) {
        self.repository = repository
    }
    
    var visibleProjects: [ProjectReport] {
        projects
            .filter(matchesSearch)
            .filter(matchesFilter)
            .sorted {
                if $0.updatedAt == $1.updatedAt {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.updatedAt > $1.updatedAt
            }
    }
    
    var linesOfBusiness: [String] {
        LineOfBusiness.options
    }
    
    var hasSearch: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    func loadProjects() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        do {
            let loadedProjects = try await repository.fetchProjects()
            try Task.checkCancellation()
            projects = loadedProjects
            storageWarnings = repository.loadWarnings
        } catch is CancellationError {
            // A cancelled view task should not display an error.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func clearFilters() {
        filter = ProjectBrowserFilter()
    }
    
    /// Create a project and return it only after the repository saves successfully.
    func createProject(codeName: String, lineOfBusiness: String,
                       status: ProjectStatus, projectSize: ProjectSize? = nil) async -> ProjectReport? {
        guard !isSaving else { return nil }
        let name = codeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let business = lineOfBusiness.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, LineOfBusiness.options.contains(business) else {
            actionErrorMessage = "Enter a project code name and select a supported product line."
            return nil
        }
        
        isSaving = true
        actionErrorMessage = nil
        defer { isSaving = false }
        
        let now = Date()
        let project = ProjectReport(
            id: UUID(),
            codeName: name,
            lineOfBusiness: business,
            status: status,
            projectSize: projectSize,
            createdAt: now,
            updatedAt: now
        )
        
        do {
            try await repository.save(project)
            projects.append(project)
            // Reveal the newly created project even when filters were active.
            searchText = ""
            clearFilters()
            return project
        } catch {
            actionErrorMessage = error.localizedDescription
            return nil
        }
    }
    
    func duplicateProject(_ project: ProjectReport, codeName: String) async -> Bool {
        guard !isSaving else { return false }
        isSaving = true
        actionErrorMessage = nil
        defer { isSaving = false }
        do {
            _ = try await repository.duplicate(id: project.id, codeName: codeName)
            searchText = ""
            clearFilters()
            await loadProjects()
            return true
        } catch {
            actionErrorMessage = error.localizedDescription
            return false
        }
    }

    func deleteProject(_ project: ProjectReport) async {
        guard !isSaving else { return }
        isSaving = true
        actionErrorMessage = nil
        defer { isSaving = false }
        
        do {
            try await repository.delete(project)
            await loadProjects()
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }
    
    func archiveProject(_ project: ProjectReport) async {
        guard !isSaving else { return }
        isSaving = true
        actionErrorMessage = nil
        defer { isSaving = false }
        do {
            guard var current = try await repository.fetchProject(id: project.id) else { throw StorageError.projectMissing }
            current.status = .archived
            // Keep the content revision so an existing unsaved recovery remains valid.
            try await repository.save(current)
            await loadProjects()
        } catch { actionErrorMessage = error.localizedDescription }
    }

    private func matchesSearch(_ project: ProjectReport) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty
        || project.codeName.localizedCaseInsensitiveContains(query)
        || project.lineOfBusiness.localizedCaseInsensitiveContains(query)
    }
    
    private func matchesFilter(_ project: ProjectReport) -> Bool {
        let matchesStatus = filter.statuses.isEmpty || filter.statuses.contains(project.status)
        let matchesBusiness = filter.linesOfBusiness.isEmpty
        || filter.linesOfBusiness.contains(project.lineOfBusiness)
        let matchesHealth: Bool
        if filter.healthStatuses.isEmpty {
            matchesHealth = true
        } else if let health = project.card?.health.ragStatus {
            matchesHealth = filter.healthStatuses.contains(health)
        } else {
            matchesHealth = false
        }
        return matchesStatus && matchesBusiness && matchesHealth
    }
}
