import Foundation

@MainActor
final class UserDefaultsSettingsRepository: SettingsRepository {
    private let defaults: UserDefaults
    private let initialSettings: AppSettings
    private let key = "applicationSettings.v1"

    init(defaults: UserDefaults = .standard, initialSettings: AppSettings = .default) {
        self.defaults = defaults
        self.initialSettings = initialSettings
    }

    func load() -> AppSettings {
        guard let data = defaults.data(forKey: key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
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
