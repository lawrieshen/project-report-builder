//
//  ProjectRepository.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

import Foundation

/// Provide main-actor access to saved projects independently of storage technology.
@MainActor
protocol ProjectRepository {
    /// Describe recoverable loading problems while valid projects remain available.
    var loadWarnings: [String] { get }
    /// Load available saved projects.
    ///
    /// - Returns: Projects supplied by the repository.
    /// - Throws: An error if loading cannot complete.
    func fetchProjects() async throws -> [ProjectReport]
    
    /// Fetch a project by stable identity.
    ///
    /// - Parameter id: The stable project identifier.
    /// - Returns: The matching project, or nil if it no longer exists.
    /// - Throws: An error if the repository cannot complete the lookup.
    func fetchProject(id: UUID) async throws -> ProjectReport?

    /// Persist a project snapshot.
    ///
    /// - Parameter project: The complete project to create or update.
    /// - Throws: An error if persistence fails.
    func save(_ project: ProjectReport) async throws
    
    /// Create an independent copy of a saved project.
    ///
    /// - Parameters:
    ///   - id: The saved source project identifier.
    ///   - codeName: The name assigned to the copy.
    /// - Returns: The duplicated project with independent identity.
    /// - Throws: An error if the source or its assets cannot be copied.
    ///   The default implementation does not support duplication.
    func duplicate(id: UUID, codeName: String) async throws -> ProjectReport

    /// Delete a saved project through its repository.
    ///
    /// - Parameter project: The project to delete.
    /// - Throws: An error if deletion cannot complete.
    func delete(_ project: ProjectReport) async throws
}

extension ProjectRepository {
    var loadWarnings: [String] { [] }
    func duplicate(id: UUID, codeName: String) async throws -> ProjectReport {
        throw StorageError.writeFailed("project copy")
    }
}
