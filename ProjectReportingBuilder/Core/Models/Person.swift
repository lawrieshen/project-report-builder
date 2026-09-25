//
//  Person.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 25/9/2026.
//

import Foundation

struct Person: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var role: String?
    
    // TODO: Email, avatar, directory integration, etc.
}
