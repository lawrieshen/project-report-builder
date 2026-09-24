//
//  ProjectReportingBuilderApp.swift
//  Project Report Builder
//
//  Created by Lawrence Shen on 24/9/2026.
//

import SwiftUI
import SwiftData

@main
struct ProjectReportingBuilderApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ProjectBrowserView()
        }
        .modelContainer(sharedModelContainer)
    }
}
