//
//  ProjectReport.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

import Foundation

/// Represent a saved project and its optional assembled report card.
nonisolated struct ProjectReport: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    
    var codeName: String
    var lineOfBusiness: String
    var status: ProjectStatus
    var projectSize: ProjectSize? = nil
    
    var card: SnippetCard?
    
    var createdAt: Date
    var updatedAt: Date
}
