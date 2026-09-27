import Foundation

/// Persist workspace restoration metadata independently of report contents.
@MainActor
protocol SessionRepository {
    func load() -> AppSessionState
    func save(_ state: AppSessionState)
}
