//
//  ProjectRepository.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

@MainActor
protocol ProjectRepository {
    func fetchProjects() async throws -> [ProjectReport]
    
    func save(_ project: ProjectReport) async throws
    
    func delete(_ project: ProjectReport) async throws
}
