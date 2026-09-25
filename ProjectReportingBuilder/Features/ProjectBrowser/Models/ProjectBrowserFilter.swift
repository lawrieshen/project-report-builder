//
//  ProjectBrowserFilter.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

import SwiftUI

struct ProjectBrowserFilter {
    var statuses: Set<ProjectStatus> = []
    var healthStatuses: Set<RAGStatus> = []
    var linesOfBusiness: Set<String> = []
    
    var isEmpty: Bool {
        statuses.isEmpty && healthStatuses.isEmpty && linesOfBusiness.isEmpty
    }
}
