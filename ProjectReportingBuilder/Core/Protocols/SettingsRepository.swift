import Foundation

/// Load and persist application preferences independently of report storage.
@MainActor
protocol SettingsRepository {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}
