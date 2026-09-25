import Foundation

@MainActor
final class InMemoryProjectRepository: ProjectRepository {
    private var projects: [ProjectReport]

    init(projects: [ProjectReport] = []) {
        self.projects = projects
    }

    func fetchProjects() async throws -> [ProjectReport] {
        projects
    }

    func fetchProject(id: UUID) async throws -> ProjectReport? {
        projects.first { $0.id == id }
    }

    func save(_ project: ProjectReport) async throws {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.append(project)
        }
    }

    func delete(_ project: ProjectReport) async throws {
        projects.removeAll { $0.id == project.id }
    }
}
