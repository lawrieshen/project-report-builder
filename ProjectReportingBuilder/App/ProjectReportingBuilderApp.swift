import SwiftUI

@main
struct ProjectReportingBuilderApp: App {
    private let environment: AppEnvironment?
    private let startupError: String?

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

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
                            settings: environment.settings, session: environment.session, maintenance: environment.maintenance)
                    .preferredColorScheme(environment.settings.settings.appearance.colorScheme)
                    .onAppear {
                        appDelegate.session = environment.session
                        environment.session.beginSession()
                    }
            } else {
                ContentUnavailableView("Unable to open local storage", systemImage: "externaldrive.badge.exclamationmark",
                                       description: Text(startupError ?? "Please reopen the app."))
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
        .commands { AppCommands() }
        Settings {
            if let environment {
                AppSettingsView(store: environment.settings, account: environment.cloudAccount, transfers: environment.cloudTransfers, fileStore: environment.store, maintenance: environment.maintenance)
                    .preferredColorScheme(environment.settings.settings.appearance.colorScheme)
            }
        }
    }
}
