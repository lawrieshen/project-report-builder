//
//  Milestone.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 25/9/2026.
//

import SwiftUI

nonisolated struct Milestone: Codable, Equatable, Sendable {
    var phase: String
    var deadline: Date
}
