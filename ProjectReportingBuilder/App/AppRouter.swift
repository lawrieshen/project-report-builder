import Foundation
import Observation

/// Coordinate app navigation without discarding unsaved report edits.
@MainActor
@Observable
final class AppRouter {
    private(set) var route: AppRoute?
    private(set) var editor: ReportEditorViewModel?
    var showingNewProject = false
    var showingLeaveConfirmation = false
    private var pendingDestination: Destination?
    private let recoveryRepository: (any DraftRecoveryRepository)?
    private let maintenance: RecoveryMaintenanceCoordinator?
    private let session: AppSessionStore?
    private var hasRestoredSession = false
    private var navigationRevision = 0
    private(set) var restorationMessage: String?
    private let settings: AppSettingsStore?
    private let repository: ProjectRepository
    private let assetFactory: (UUID) -> any AssetRepository

    private enum Destination {
        case browser
        case newProject
        case editor(UUID)
    }

    init(repository: ProjectRepository, assetRepository: (any AssetRepository)? = nil,
         assetFactory: ((UUID) -> any AssetRepository)? = nil,
         recoveryRepository: (any DraftRecoveryRepository)? = nil, settings: AppSettingsStore? = nil, session: AppSessionStore? = nil,
         maintenance: RecoveryMaintenanceCoordinator? = nil) {
        self.maintenance = maintenance
        self.session = session
        self.settings = settings
        self.recoveryRepository = recoveryRepository
        self.repository = repository
        let fallback = assetRepository ?? LocalAssetRepository()
        self.assetFactory = assetFactory ?? { _ in fallback }
    }

    /// Restore once, without replacing navigation that occurred during the lookup.
    func restoreSession() async {
        guard !hasRestoredSession else { return }
        hasRestoredSession = true
        guard navigationRevision == 0, let settings, let session,
              session.previousSessionWasInterrupted,
              settings.settings.restoreWorkspaceAfterInterruption,
              let id = session.state.lastOpenedProjectID else { return }
        let revision = navigationRevision
        do {
            let project = try await repository.fetchProject(id: id)
            guard navigationRevision == revision else { return }
            if project != nil {
                navigate(to: .editor(id))
            } else {
                session.state.lastOpenedProjectID = nil
            }
        } catch {
            guard navigationRevision == revision else { return }
            restorationMessage = "Unable to restore the last workspace: " + error.localizedDescription
        }
    }

    func openProject(id: UUID) {
        guard route != .reportEditor(projectID: id) else { return }
        request(.editor(id))
    }

    func showProjects() { request(.browser) }
    func newProject() { request(.newProject) }

    func cancelNavigation() {
        pendingDestination = nil
        showingLeaveConfirmation = false
        editor?.setAutosavePaused(false)
    }

    func discardAndLeave() async {
        guard maintenance?.isClearing != true, editor?.isSaving != true, editor?.isImporting != true else { return }
        guard await editor?.discardChanges() == true else {
            cancelNavigation()
            return
        }
        completePendingNavigation()
    }

    func saveAndLeave() async {
        guard let editor, await editor.save(), !editor.isDirty else {
            cancelNavigation()
            return
        }
        completePendingNavigation()
    }

    private func request(_ destination: Destination) {
        navigationRevision += 1
        restorationMessage = nil
        guard maintenance?.isClearing != true, editor?.isSaving != true, editor?.isImporting != true else { return }
        if editor?.isDirty == true {
            pendingDestination = destination
            editor?.setAutosavePaused(true)
            showingLeaveConfirmation = true
        } else {
            navigate(to: destination)
        }
    }

    private func completePendingNavigation() {
        guard let destination = pendingDestination else { return }
        cancelNavigation()
        navigate(to: destination)
    }

    private func navigate(to destination: Destination) {
        editor?.setAutosavePaused(true)
        showingNewProject = false
        switch destination {
        case .browser, .newProject:
            route = nil
            editor = nil
            maintenance?.participant = nil
            if case .newProject = destination { showingNewProject = true }
        case .editor(let id):
            session?.state.lastOpenedProjectID = id
            editor = ReportEditorViewModel(projectID: id, repository: repository, assetRepository: assetFactory(id), recoveryRepository: recoveryRepository, settings: settings)
            maintenance?.participant = editor
            route = .reportEditor(projectID: id)
        }
    }
}
