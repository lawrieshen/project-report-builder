//
//  Person.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 25/9/2026.
//

import Foundation

nonisolated struct Person: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var role: String?
    
    // TODO: Email, avatar, directory integration, etc.
}
