//
//  ProjectBrowserViewModel.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ProjectBrowserViewModel {
    
    var projects: [ProjectReport] = []
    
    var searchText = ""
    var filter = ProjectBrowserFilter()
    
    var isLoading = false
    var errorMessage: String?
    
    private let repository: ProjectRepository
    
    init(repository: ProjectRepository) {
        self.repository = repository
    }
    
    var filteredProjects: [ProjectReport] {
        projects.filter { project in
            matchesSearch(project) && matchesFilter(project)
        }
    }
}

private extension ProjectBrowserViewModel {
    
    func matchesSearch(_ project: ProjectReport) -> Bool {
        guard !searchText.isEmpty else {
            return true
        }
        
        return project.codeName.localizedCaseInsensitiveContains(searchText)
        || project.lineOfBusiness.localizedStandardContains(searchText)
    }
    
    func matchesFilter(_ project: ProjectReport) -> Bool {
        if !filter.statuses.isEmpty, !filter.statuses.contains(project.status) {
            return false
        }
        
        if !filter.linesOfBusiness.isEmpty, !filter.linesOfBusiness.contains(project.lineOfBusiness) {
            return false
        }
        
        return true
    }
}
