//
//  Person.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 25/9/2026.
//

import SwiftUI

struct Person: Identifiable, Codable, Equatable {
    var id: Int
    var name: String
    var role: String?
    
    // TODO: Email, avatar, directory integration, etc.
}
