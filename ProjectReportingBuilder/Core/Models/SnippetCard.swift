//
//  SnippetCard.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 25/9/2026.
//

import Foundation

struct SnippetCard: Identifiable, Codable, Equatable {
    let id: UUID
    
    var health: ProjectHealth
    var summary: ExecutiveSummary
    var accountability: Accountability
    
    var assets: [ImageAsset] = []
    var metrics: [EngineeringMetric] = []

    private enum CodingKeys: String, CodingKey {
        case id, health, summary, accountability, metrics, assets
    }

}

// Keep the memberwise initializer available while supporting Feature 02 data.
extension SnippetCard {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        health = try values.decode(ProjectHealth.self, forKey: .health)
        summary = try values.decode(ExecutiveSummary.self, forKey: .summary)
        accountability = try values.decode(Accountability.self, forKey: .accountability)
        assets = try values.decodeIfPresent([ImageAsset].self, forKey: .assets) ?? []
        metrics = try values.decodeIfPresent([EngineeringMetric].self, forKey: .metrics) ?? []
    }
}
