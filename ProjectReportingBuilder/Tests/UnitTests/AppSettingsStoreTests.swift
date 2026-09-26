import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
final class MemorySettingsRepository: SettingsRepository {
    var value: AppSettings
    var saveCount = 0
    init(_ value: AppSettings = .default) { self.value = value }
    func load() -> AppSettings { value }
    func save(_ settings: AppSettings) { value = settings; saveCount += 1 }
}

@MainActor
struct AppSettingsStoreTests {
    @Test func sharedUpdatesPersistAndDefaultsNotifyObservers() {
        let repository = MemorySettingsRepository()
        let store = AppSettingsStore(repository: repository)
        let observer = SettingsSpy()
        store.observe(observer)
        store.settings.appearance = .dark
        #expect(repository.saveCount == 1)
        #expect(observer.values.last?.appearance == .dark)
        store.settings.appearance = .dark
        #expect(repository.saveCount == 1)
        store.restoreDefaults()
        #expect(observer.values.last == .default)
        #expect(repository.value == .default)
    }
}

@MainActor
private final class SettingsSpy: AppSettingsObserving {
    var values: [AppSettings] = []
    func settingsDidChange(_ settings: AppSettings) { values.append(settings) }
}
