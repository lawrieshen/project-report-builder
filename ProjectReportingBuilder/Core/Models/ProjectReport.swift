//
//  ProjectReport.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

import Foundation

nonisolated struct ProjectReport: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    
    var codeName: String
    var lineOfBusiness: String
    var status: ProjectStatus
    
    var card: SnippetCard?
    
    var createdAt: Date
    var updatedAt: Date
}
