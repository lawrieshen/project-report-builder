//
//  ProjectRepository.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

import Foundation

@MainActor
protocol ProjectRepository {
    func fetchProjects() async throws -> [ProjectReport]
    
    /// Fetch a project by stable identity.
    /// - Returns: The matching project, or nil if it no longer exists.
    /// - Throws: An error if the repository cannot complete the lookup.
    func fetchProject(id: UUID) async throws -> ProjectReport?

    func save(_ project: ProjectReport) async throws
    
    func delete(_ project: ProjectReport) async throws
}
