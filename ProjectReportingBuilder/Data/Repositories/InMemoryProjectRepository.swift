//
//  InMemoryProjectRepository.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

final class InMemoryProjectRepository: ProjectRepository {

    private var projects: [ProjectReport]
    
    init(projects: [ProjectReport]) {
        self.projects = projects
    }
    
    func fetchProjects() async throws -> [ProjectReport] {
        return projects
    }
    
    func save(_ project: ProjectReport) async throws {
        // MVP implementation
    }
    
    func delete(_ project: ProjectReport) async throws {
        projects.removeAll {
            $0.id == project.id
        }
    }
}
