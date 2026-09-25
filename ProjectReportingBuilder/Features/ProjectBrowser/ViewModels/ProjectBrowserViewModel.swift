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
    var actionErrorMessage: String?
    var route: AppRoute?
    
    private let repository: ProjectRepository
    
    init(repository: ProjectRepository) {
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
        Array(Set(projects.map { $0.lineOfBusiness })).sorted()
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
        } catch is CancellationError {
            // A cancelled view task should not display an error.
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func selectProject(_ project: ProjectReport) {
        route = .reportEditor(projectID: project.id)
    }
    
    func clearFilters() {
        filter = ProjectBrowserFilter()
    }
    
    func createProject(codeName: String, lineOfBusiness: String,
                       status: ReportStatus) async -> Bool {
        guard !isSaving else { return false }
        let name = codeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let business = lineOfBusiness.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !business.isEmpty else {
            actionErrorMessage = "Enter a project code name and line of business."
            return false
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
            createdAt: now,
            updatedAt: now
        )
        
        do {
            try await repository.save(project)
            projects.append(project)
            // Reveal the newly created project even when filters were active.
            searchText = ""
            clearFilters()
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
            projects.removeAll { $0.id == project.id }
            if route == .reportEditor(projectID: project.id) {
                route = nil
            }
        } catch {
            actionErrorMessage = error.localizedDescription
        }
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
        return matchesStatus && matchesBusiness
    }
}
