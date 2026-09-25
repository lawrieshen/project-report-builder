import Foundation

/// Expose background file storage through the existing feature contract.
@MainActor
final class LocalProjectRepository: ProjectRepository {
    let store: ProjectFileStore
    private(set) var loadWarnings: [String] = []

    init(store: ProjectFileStore) { self.store = store }

    func fetchProjects() async throws -> [ProjectReport] {
        let result = try await store.fetchProjects()
        loadWarnings = result.warnings
        return result.projects
    }

    func fetchProject(id: UUID) async throws -> ProjectReport? { try await store.fetchProject(id: id) }
    func save(_ project: ProjectReport) async throws { try await store.save(project) }
    func delete(_ project: ProjectReport) async throws { try await store.delete(id: project.id) }
}
