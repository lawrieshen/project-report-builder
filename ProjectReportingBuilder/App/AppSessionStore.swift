/// Persist session markers while retaining the previous launch state for recovery decisions.
@MainActor
final class AppSessionStore {
    /// Capture the stored running marker before this session updates it.
    ///
    /// An unfinished marker can indicate a crash, force quit, or another interrupted exit.
    let previousSessionWasInterrupted: Bool

    var state: AppSessionState {
        didSet {
            if state != oldValue {
                repository.save(state)
            }
        }
    }

    private let repository: any SessionRepository

    init(repository: any SessionRepository) {
        self.repository = repository

        let savedState = repository.load()
        state = savedState
        previousSessionWasInterrupted = savedState.wasRunning
    }

    /// Mark the current app session as running.
    func beginSession() {
        state.wasRunning = true
    }

    /// Mark the current app session as normally terminated.
    func endSession() {
        state.wasRunning = false
    }
}
