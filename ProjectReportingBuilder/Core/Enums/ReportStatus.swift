//
//  ReportStatus.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

enum ReportStatus: String, Codable, CaseIterable {
    case onTrack
    case atRisk
    case blocked
    case draft
    case archived
}
