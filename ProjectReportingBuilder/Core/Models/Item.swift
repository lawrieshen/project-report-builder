//
//  Item.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
