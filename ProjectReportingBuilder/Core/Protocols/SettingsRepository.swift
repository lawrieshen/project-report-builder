import Foundation

@MainActor
protocol SettingsRepository {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}
