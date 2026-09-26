import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct AppSessionStoreTests {
    @Test func legacySessionDefaultsToNormalExit() throws {
        let suite = "SessionTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let id = UUID()
        defaults.set(id.uuidString, forKey: "lastOpenedProjectID.v1")

        let state = UserDefaultsSessionRepository(defaults: defaults).load()
        #expect(state.lastOpenedProjectID == id)
        #expect(!state.wasRunning)
    }

    @Test func normalTerminationClearsPersistedRunningFlag() throws {
        let suite = "SessionTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let repository = UserDefaultsSessionRepository(defaults: defaults)
        let session = AppSessionStore(repository: repository)
        session.beginSession()
        #expect(repository.load().wasRunning)
        #expect(!session.previousSessionWasInterrupted)

        let interrupted = AppSessionStore(repository: repository)
        #expect(interrupted.previousSessionWasInterrupted)
        let delegate = AppDelegate()
        delegate.session = session
        delegate.applicationWillTerminate(Notification(name: Notification.Name("terminationTest")))
        #expect(!repository.load().wasRunning)
        #expect(!AppSessionStore(repository: repository).previousSessionWasInterrupted)
    }

}
