import SwiftUI

@main
struct ProjectReportingBuilderApp: App {
    private let environment: AppEnvironment?
    private let startupError: String?

    init() {
        do {
            environment = try AppEnvironment.live()
            startupError = nil
        } catch {
            environment = nil
            startupError = error.localizedDescription
        }
    }

    var body: some Scene {
        // One editing window prevents two workspaces overwriting the same draft.
        Window("Project Reporting Builder", id: "main") {
            if let environment {
                ContentView(repository: environment.projects, assetFactory: environment.assets)
            } else {
                ContentUnavailableView("Unable to open local storage", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text(startupError ?? "Please reopen the app."))
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
    }
}
