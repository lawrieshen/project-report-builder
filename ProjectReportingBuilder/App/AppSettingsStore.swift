import Foundation
import Observation

@MainActor
protocol AppSettingsObserving: AnyObject {
    func settingsDidChange(_ settings: AppSettings)
}

@MainActor
private final class SettingsObserver {
    weak var value: (any AppSettingsObserving)?
    init(_ value: any AppSettingsObserving) { self.value = value }
}

/// Publish one shared set of preferences and persist each actual change.
@MainActor
@Observable
final class AppSettingsStore {
    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            repository.save(settings)
            observers.removeAll { $0.value == nil }
            for observer in observers { observer.value?.settingsDidChange(settings) }
        }
    }
    private let repository: any SettingsRepository
    @ObservationIgnored private var observers: [SettingsObserver] = []

    init(repository: any SettingsRepository) {
        self.repository = repository
        settings = repository.load()
    }

    func observe(_ observer: any AppSettingsObserving) {
        observers.removeAll { $0.value == nil || $0.value === observer }
        observers.append(SettingsObserver(observer))
        observer.settingsDidChange(settings)
    }

    func restoreDefaults() { settings = .default }
}
