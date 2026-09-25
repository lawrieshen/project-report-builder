//
//  ProjectHealth.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 25/9/2026.
//

import SwiftUI

nonisolated struct ProjectHealth: Codable, Equatable, Sendable {
    var ragStatus: RAGStatus?
    var milestone: Milestone?
}
