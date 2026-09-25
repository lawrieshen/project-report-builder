//
//  RAGStatus.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 25/9/2026.
//

// Manage project health status
nonisolated enum RAGStatus: String, Codable, CaseIterable, Sendable {
    case green
    case amber
    case red
}
