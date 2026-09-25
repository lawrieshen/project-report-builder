//
//  ProjectReport.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

import SwiftUI

struct ProjectReport: Identifiable, Codable, Equatable {
    let id: UUID
    
    var codeName: String
    var lineOfBusiness: String
    var status: ReportStatus
    
    var template: ReportTemplate?
    var card: SnippetCard?
    
    var createdAt: Date
    var updatedAt: Date
}
