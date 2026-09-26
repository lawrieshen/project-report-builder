import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct SettingsRepositoryTests {
    @Test(arguments: [false, true])
    func migratesLegacyPreferences(lastProject: Bool) throws {
        let suite = "SettingsTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let legacy: [String: Any] = [
            "autosaveEnabled": false, "autosaveDelay": 5, "appearance": "dark",
            "restoreLastWorkspace": false,
            "defaultLaunchDestination": lastProject ? "lastOpenedProject" : "projectBrowser",
            "confirmBeforeDelete": false, "showRecoveryPrompt": false
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "applicationSettings.v1")
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        let settings = repository.load()
        #expect(settings.restoreWorkspaceAfterInterruption == lastProject)
        #expect(!settings.autosaveEnabled)
        #expect(settings.autosaveDelay == .seconds5)
        #expect(settings.appearance == .dark)
        #expect(!settings.confirmBeforeDelete)
        #expect(!settings.showRecoveryPrompt)
        repository.save(settings)
        #expect(repository.load() == settings)
    }

    @Test func defaultsPersistenceAndInvalidPreferences() throws {
        let suite = "SettingsTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsSettingsRepository(defaults: defaults)
        #expect(repository.load() == .default)
        var settings = AppSettings.default
        settings.appearance = .dark
        settings.autosaveEnabled = false
        settings.autosaveDelay = .seconds5
        settings.restoreWorkspaceAfterInterruption = false
        settings.confirmBeforeDelete = false
        settings.showRecoveryPrompt = false
        repository.save(settings)
        #expect(UserDefaultsSettingsRepository(defaults: defaults).load() == settings)
        defaults.set(Data("broken".utf8), forKey: "applicationSettings.v1")
        #expect(repository.load() == .default)
        #expect(AutosaveDelay(rawValue: 3) == nil)
    }
}
