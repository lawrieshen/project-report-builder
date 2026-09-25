//
//  SnippetCard.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 25/9/2026.
//

import SwiftUI

struct SnippetCard: Identifiable, Codable, Equatable {
    let id: UUID
    
    var health: ProjectHealth
    var summary: ExecutiveSummary
    var accountability: Accountability
    
    // TODO: Metrics
}
