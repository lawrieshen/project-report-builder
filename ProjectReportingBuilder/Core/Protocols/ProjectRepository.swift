//
//  ProjectRepository.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

import Foundation

/// Provide report persistence without exposing the storage implementation to views.
@MainActor
protocol ProjectRepository {
    /// Expose nonfatal problems encountered while loading available reports.
    var loadWarnings: [String] { get }
    /// Load the available reports.
    /// - Returns: Reports accessible through this repository.
    /// - Throws: An error if the repository cannot complete the load.
    func fetchProjects() async throws -> [ProjectReport]
    
    /// Fetch a project by stable identity.
    /// - Returns: The matching project, or nil if it no longer exists.
    /// - Throws: An error if the repository cannot complete the lookup.
    func fetchProject(id: UUID) async throws -> ProjectReport?

    /// Persist a report using its stable identity.
    /// - Parameter project: The report snapshot to store.
    /// - Throws: A storage, validation, or conflict error from the implementation.
    func save(_ project: ProjectReport) async throws
    
    /// Create an independent copy when supported by the repository.
    /// - Parameters:
    ///   - id: The source report identity.
    ///   - codeName: The name for the copy.
    /// - Returns: The newly stored report.
    /// - Throws: An error if copying is unsupported or cannot complete.
    func duplicate(id: UUID, codeName: String) async throws -> ProjectReport

    /// Remove the stored report identified by the supplied snapshot.
    /// - Parameter project: The report to remove.
    /// - Throws: An error if deletion cannot complete.
    func delete(_ project: ProjectReport) async throws
}

extension ProjectRepository {
    var loadWarnings: [String] { [] }
    func duplicate(id: UUID, codeName: String) async throws -> ProjectReport {
        throw StorageError.writeFailed("project copy")
    }
}
