import Foundation

@MainActor
final class UserDefaultsSessionRepository: SessionRepository {
    private let defaults: UserDefaults
    private let key = "lastOpenedProjectID.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> AppSessionState {
        AppSessionState(lastOpenedProjectID: defaults.string(forKey: key).flatMap(UUID.init(uuidString:)))
    }

    func save(_ state: AppSessionState) {
        defaults.set(state.lastOpenedProjectID?.uuidString, forKey: key)
    }
}
