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
    private let repository: ProjectRepository
    private let assetFactory: (UUID) -> any AssetRepository

    private enum Destination {
        case browser
        case newProject
        case editor(UUID)
    }

    init(repository: ProjectRepository, assetRepository: (any AssetRepository)? = nil,
         assetFactory: ((UUID) -> any AssetRepository)? = nil,
         recoveryRepository: (any DraftRecoveryRepository)? = nil) {
        self.recoveryRepository = recoveryRepository
        self.repository = repository
        let fallback = assetRepository ?? LocalAssetRepository()
        self.assetFactory = assetFactory ?? { _ in fallback }
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
    }

    func discardAndLeave() async {
        guard editor?.isSaving != true, editor?.isImporting != true else { return }
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
        guard editor?.isSaving != true, editor?.isImporting != true else { return }
        if editor?.isDirty == true {
            pendingDestination = destination
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
        showingNewProject = false
        switch destination {
        case .browser, .newProject:
            route = nil
            editor = nil
            if case .newProject = destination { showingNewProject = true }
        case .editor(let id):
            editor = ReportEditorViewModel(projectID: id, repository: repository, assetRepository: assetFactory(id), recoveryRepository: recoveryRepository)
            route = .reportEditor(projectID: id)
        }
    }
}
