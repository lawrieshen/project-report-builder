import Foundation

/// Persist preferences and migrate legacy workspace restoration keys when loading.
@MainActor
final class UserDefaultsSettingsRepository: SettingsRepository {
    private let defaults: UserDefaults
    private let initialSettings: AppSettings
    private let key = "applicationSettings.v1"

    init(defaults: UserDefaults = .standard, initialSettings: AppSettings = .default) {
        self.defaults = defaults
        self.initialSettings = initialSettings
    }

    /// Load preferences while preserving legacy restoration choices.
    /// - Returns: Decoded settings, or the injected initial settings for missing or unreadable data.
    func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              var values = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return initialSettings
        }
        // Preserve the effective legacy preference without resetting other settings.
        if values["restoreWorkspaceAfterInterruption"] == nil {
            let restore = values["restoreLastWorkspace"] as? Bool ?? true
            let lastProject = values["defaultLaunchDestination"] as? String == "lastOpenedProject"
            values["restoreWorkspaceAfterInterruption"] = restore || lastProject
        }
        values.removeValue(forKey: "restoreLastWorkspace")
        values.removeValue(forKey: "defaultLaunchDestination")
        guard let migratedData = try? JSONSerialization.data(withJSONObject: values),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: migratedData) else {
            return initialSettings
        }
        return settings
    }

    func save(_ settings: AppSettings) {
        // All fields are finite, constrained preference values.
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: key)
    }
}
