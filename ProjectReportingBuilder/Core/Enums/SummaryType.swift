//
//  SummaryType.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 25/9/2026.
//

nonisolated enum SummaryType: String, Codable, CaseIterable, Sendable {
    case update
    case blocker
    case ask
}
