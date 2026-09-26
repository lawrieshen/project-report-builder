import Foundation

@MainActor
protocol SessionRepository {
    func load() -> AppSessionState
    func save(_ state: AppSessionState)
}
