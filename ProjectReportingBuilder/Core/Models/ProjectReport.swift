//
//  ProjectReport.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

import Foundation

struct ProjectReport: Identifiable, Codable, Hashable {
    let id: UUID
    var codeName: String
    var lineOfBusiness: String
    var status: ReportStatus
    var createdAt: Date
    var updatedAt: Date
}
