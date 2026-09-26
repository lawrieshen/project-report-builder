import Foundation

nonisolated enum AppAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case system, light, dark
    var id: Self { self }
}

nonisolated enum AutosaveDelay: Int, Codable, CaseIterable, Identifiable, Sendable {
    case seconds1 = 1, seconds2 = 2, seconds5 = 5
    var id: Self { self }
}

nonisolated enum LaunchDestination: String, Codable, CaseIterable, Identifiable, Sendable {
    case projectBrowser, lastOpenedProject
    var id: Self { self }
}

/// Keep application preferences separate from report content and session metadata.
nonisolated struct AppSettings: Codable, Equatable, Sendable {
    var autosaveEnabled = true
    var autosaveDelay: AutosaveDelay = .seconds2
    var appearance: AppAppearance = .system
    var restoreLastWorkspace = true
    var defaultLaunchDestination: LaunchDestination = .projectBrowser
    var confirmBeforeDelete = true
    var showRecoveryPrompt = true

    static let `default` = AppSettings()
}
