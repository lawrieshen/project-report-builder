import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct WorkspaceRestorationTests {
    @Test func normalLaunchKeepsBrowserEvenWithLastWorkspacePreference() async {
        let report = project()
        let session = AppSessionStore(repository: MemorySessionRepository(
            AppSessionState(lastOpenedProjectID: report.id)))
        let settings = AppSettingsStore(repository: MemorySettingsRepository())
        session.beginSession()
        let router = AppRouter(repository: WorkspaceTestRepository(project: report),
                               settings: settings, session: session)
        await router.restoreSession()
        #expect(router.route == nil)
        #expect(session.state.lastOpenedProjectID == report.id)
    }

    private func project() -> ProjectReport {
        ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone",
                      status: .active, createdAt: .now, updatedAt: .now)
    }

    @Test func sessionPersistsSeparatelyAndMissingProjectFallsBack() async throws {
        let suite = "SessionTests." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let session = AppSessionStore(repository: UserDefaultsSessionRepository(defaults: defaults))
        #expect(session.state.lastOpenedProjectID == nil)
        let report = project()
        session.state.lastOpenedProjectID = report.id
        session.beginSession()
        let reopened = AppSessionStore(repository: UserDefaultsSessionRepository(defaults: defaults))
        #expect(reopened.state.lastOpenedProjectID == report.id)
        let settings = AppSettingsStore(repository: MemorySettingsRepository())
        let router = AppRouter(repository: WorkspaceTestRepository(project: nil), settings: settings, session: reopened)
        await router.restoreSession()
        #expect(router.route == nil)
        #expect(reopened.state.lastOpenedProjectID == nil)
    }

    @Test func interruptedSessionRespectsRestorationPreference() async {
        let report = project()
        let repository = WorkspaceTestRepository(project: report)
        let session = AppSessionStore(repository: MemorySessionRepository(AppSessionState(lastOpenedProjectID: report.id, wasRunning: true)))
        let settings = AppSettingsStore(repository: MemorySettingsRepository())
        let restored = AppRouter(repository: repository, settings: settings, session: session)
        await restored.restoreSession()
        #expect(restored.route == .reportEditor(projectID: report.id))
        #expect(repository.saveCount == 0)
        settings.settings.restoreWorkspaceAfterInterruption = false
        let browser = AppRouter(repository: repository, settings: settings, session: session)
        await browser.restoreSession()
        #expect(browser.route == nil)

    }

    @Test func userNavigationWinsAndLookupFailureKeepsBrowser() async {
        let report = project()
        let repository = WorkspaceTestRepository(project: report)
        let session = AppSessionStore(repository: MemorySessionRepository(AppSessionState(lastOpenedProjectID: report.id, wasRunning: true)))
        let settings = AppSettingsStore(repository: MemorySettingsRepository())
        let router = AppRouter(repository: repository, settings: settings, session: session)
        router.newProject()
        await router.restoreSession()
        #expect(router.showingNewProject)
        #expect(router.route == nil)
        repository.failLoad = true
        let failing = AppRouter(repository: repository, settings: settings, session: session)
        await failing.restoreSession()
        #expect(failing.route == nil)
        #expect(failing.restorationMessage != nil)
    }
}

@MainActor
private final class MemorySessionRepository: SessionRepository {
    var state: AppSessionState
    init(_ state: AppSessionState) { self.state = state }
    func load() -> AppSessionState { state }
    func save(_ state: AppSessionState) { self.state = state }
}
