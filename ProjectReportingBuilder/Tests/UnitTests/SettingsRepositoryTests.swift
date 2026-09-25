import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct SettingsRepositoryTests {
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
        settings.restoreLastWorkspace = false
        settings.defaultLaunchDestination = .lastOpenedProject
        settings.confirmBeforeDelete = false
        settings.showRecoveryPrompt = false
        repository.save(settings)
        #expect(UserDefaultsSettingsRepository(defaults: defaults).load() == settings)
        defaults.set(Data("broken".utf8), forKey: "applicationSettings.v1")
        #expect(repository.load() == .default)
        #expect(AutosaveDelay(rawValue: 3) == nil)
    }
}
