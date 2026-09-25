//
//  ExecutiveSummary.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 25/9/2026.
//

import SwiftUI

nonisolated struct ExecutiveSummary: Codable, Equatable, Sendable {
    var type: SummaryType
    var message: String
}
