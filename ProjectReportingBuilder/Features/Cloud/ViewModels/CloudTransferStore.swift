import Foundation
import Observation

extension Notification.Name {
    static let cloudProjectImported = Notification.Name("cloudProjectImported")
}

/// Coordinate explicit report transfers and track per-project migration outcomes.
@MainActor @Observable
final class CloudTransferStore {
    private(set) var localProjects: [ProjectReport] = []
    private(set) var cloudReports: [CloudReport] = []
    private(set) var nextCursor: UUID?
    private(set) var isBusy = false
    private(set) var migrationResults: [UUID: String] = [:]
    private var generation = 0
    private(set) var message: String?
    private let projects: any ProjectRepository
    private let client: any CloudReportServing
    private let images: (any CloudImageTransferring)?
    private let history: any CloudUploadTracking

    init(projects: any ProjectRepository, client: any CloudReportServing, history: any CloudUploadTracking, images: (any CloudImageTransferring)? = nil) {
        self.images = images
        self.projects = projects
        self.client = client
        self.history = history
    }

    func refresh() async {
        guard !isBusy else { return }
        let operation = generation
        isBusy = true
        message = nil
        defer { if generation == operation { isBusy = false } }
        do {
            let local = try await projects.fetchProjects()
            guard operation == generation else { return }
            localProjects = local
            let page = try await client.list(after: nil)
            guard operation == generation else { return }
            cloudReports = page.items
            nextCursor = page.nextCursor
        } catch { if operation == generation { message = error.localizedDescription } }
    }

    func loadMore() async {
        guard !isBusy, let cursor = nextCursor else { return }
        let operation = generation
        isBusy = true
        defer { if generation == operation { isBusy = false } }
        do {
            let page = try await client.list(after: cursor)
            guard operation == generation else { return }
            let existing = Set(cloudReports.map(\.id))
            cloudReports += page.items.filter { !existing.contains($0.id) }
            nextCursor = page.nextCursor
        } catch { if operation == generation { message = error.localizedDescription } }
    }

    /// Upload images and report content using the last recorded cloud revision.
    ///
    /// Reconcile a conflict only when the next remote revision contains the exact
    /// attempted content. Record failures in `message` and `migrationResults`.
    /// - Parameter id: The local report identity to upload.
    func upload(id: UUID) async {
        guard !isBusy else { return }
        let operation = generation
        isBusy = true
        message = nil
        defer { if generation == operation { isBusy = false } }
        do {
            guard let project = try await projects.fetchProject(id: id) else { throw CloudTransferError.missingProject }
            let imageMetadata = try await images?.uploadImages(for: project) ?? []
            guard operation == generation else { return }
            let content = try CloudReportContent(project: project, images: imageMetadata)
            let revision = try history.revision(for: id)
            let saved: CloudReport
            do { saved = try await client.save(id: id, revision: revision, content: content) }
            catch CloudTransferError.conflict {
                let remote = try await client.get(id: id)
                // Reconcile a lost response only when the exact attempted content was saved.
                guard revision < Int64.max, remote.revision == revision + 1, remote.report == content else {
                    throw CloudTransferError.conflict
                }
                saved = remote
            }
            guard operation == generation else { return }
            guard saved.reportID == id, (1...2).contains(saved.schemaVersion), saved.revision > revision else {
                throw CloudTransferError.invalidResponse
            }
            do { try history.record(id: id, revision: saved.revision) }
            catch {
                message = "Uploaded, but the local upload record could not be saved. Retry to reconcile the cloud version."
                return
            }
            cloudReports.removeAll { $0.id == id }
            cloudReports.insert(saved, at: 0)
            message = "Uploaded \(project.codeName)."
            migrationResults[id] = "Imported successfully"
            NotificationCenter.default.post(name: .cloudProjectImported, object: nil)
        } catch { if operation == generation { message = error.localizedDescription; migrationResults[id] = error.localizedDescription } }
    }

    /// Import a cloud report as a new local copy, including supported images.
    /// - Parameter id: The cloud report identity to download.
    func download(id: UUID) async {
        guard !isBusy else { return }
        let operation = generation
        isBusy = true
        message = nil
        defer { if generation == operation { isBusy = false } }
        do {
            let remote = try await client.get(id: id)
            guard operation == generation else { return }
            guard remote.reportID == id, (1...2).contains(remote.schemaVersion), remote.revision > 0 else {
                throw CloudTransferError.invalidResponse
            }
            let copy: ProjectReport
            if let images { copy = try await images.importCopy(of: remote) }
            else {
                guard (remote.report.assets ?? []).isEmpty else { throw CloudTransferError.imagesUnsupported }
                copy = try remote.report.localCopy()
                try await projects.save(copy)
            }
            guard operation == generation else { return }
            localProjects.insert(copy, at: 0)
            NotificationCenter.default.post(name: .cloudProjectImported, object: nil)
            message = "Downloaded \(copy.codeName) as a new local project."
        } catch { if operation == generation { message = error.localizedDescription } }
    }

    /// Clear transfer UI state and reject results from earlier operations.
    ///
    /// Already-started remote writes are not rolled back.
    func clear() {
        generation += 1
        isBusy = false
        migrationResults = [:]
        localProjects = []
        cloudReports = []
        nextCursor = nil
        message = nil
    }
}
