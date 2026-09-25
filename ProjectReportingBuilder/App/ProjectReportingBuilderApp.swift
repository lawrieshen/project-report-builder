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
                ContentView(repository: environment.projects, assetFactory: environment.assets,
                            recoveryRepository: LocalDraftRecoveryRepository(store: environment.store),
                            settings: environment.settings)
                    .preferredColorScheme(environment.settings.settings.appearance.colorScheme)
            } else {
                ContentUnavailableView("Unable to open local storage", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text(startupError ?? "Please reopen the app."))
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
        Settings {
            if let environment {
                AppSettingsView(store: environment.settings, fileStore: environment.store)
                    .preferredColorScheme(environment.settings.settings.appearance.colorScheme)
            }
        }
    }
}
