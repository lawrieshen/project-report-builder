//
//  ProjectReportingBuilderApp.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

import SwiftUI

@main
struct ProjectReportingBuilderApp: App {
    private let repository = InMemoryProjectRepository(projects: [])

    var body: some Scene {
        WindowGroup {
            ContentView(repository: repository)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
    }
}
