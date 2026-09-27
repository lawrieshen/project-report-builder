import Foundation

/// Store the last project identity and interruption marker in user defaults.
@MainActor
final class UserDefaultsSessionRepository: SessionRepository {
    private let defaults: UserDefaults

    private let projectIDKey = "lastOpenedProjectID.v1"
    private let wasRunningKey = "wasRunning.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> AppSessionState {
        let projectID = defaults.string(forKey: projectIDKey)
            .flatMap(UUID.init(uuidString:))

        return AppSessionState(
            lastOpenedProjectID: projectID,
            wasRunning: defaults.bool(forKey: wasRunningKey)
        )
    }

    func save(_ state: AppSessionState) {
        defaults.set(
            state.lastOpenedProjectID?.uuidString,
            forKey: projectIDKey
        )
        defaults.set(state.wasRunning, forKey: wasRunningKey)
    }
}
