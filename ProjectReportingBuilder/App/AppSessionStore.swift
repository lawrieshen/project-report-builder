import Foundation

@MainActor
final class AppSessionStore {
    var state: AppSessionState {
        didSet {
            if state != oldValue { repository.save(state) }
        }
    }
    private let repository: any SessionRepository

    init(repository: any SessionRepository) {
        self.repository = repository
        state = repository.load()
    }
}
