import Foundation

/// Keep remote identities and revisions; never silently overwrite a conflicting report.
@MainActor
final class CloudProjectRepository: ProjectRepository {
    private let client: any CloudReportServing
    private let files: ProjectFileStore
    private let images: (any CloudProjectImages)?
    private var reports: [UUID: CloudReport] = [:]
    private var listed: [UUID: CloudReport] = [:]
    private var saving: Set<UUID> = []
    private var active = true
    private(set) var loadWarnings: [String] = []

    init(client: any CloudReportServing, files: ProjectFileStore, images: (any CloudProjectImages)? = nil) {
        self.client = client
        self.files = files
        self.images = images
    }

    /// Reject late responses from a workspace whose account session ended.
    func invalidate() { active = false; reports = [:]; listed = [:] }

    private func checkSession() throws {
        try Task.checkCancellation()
        guard active else { throw CloudTransferError.signedOut }
    }

    func fetchProjects() async throws -> [ProjectReport] {
        try checkSession()
        var result: [ProjectReport] = []
        var cursor: UUID?
        var seen: Set<UUID> = []
        repeat {
            let page = try await client.list(after: cursor)
            try checkSession()
            for report in page.items {
                let project = try mapped(report)
                // Listing must not change the revision underneath an open editor.
                listed[report.id] = report
                result.append(project)
            }
            cursor = page.nextCursor
            if let cursor, !seen.insert(cursor).inserted { throw CloudTransferError.invalidResponse }
        } while cursor != nil
        return result
    }

    func fetchProject(id: UUID) async throws -> ProjectReport? {
        try checkSession()
        let report: CloudReport
        do { report = try await client.get(id: id) }
        catch CloudTransferError.notFound { return nil }
        try checkSession()
        guard report.id == id else { throw CloudTransferError.invalidResponse }
        let project = try mapped(report)
        try await images?.cache(report: report, project: project)
        try checkSession()
        try await files.save(project)
        try checkSession()
        reports[id] = report
        return project
    }

    func save(_ project: ProjectReport) async throws {
        try checkSession()
        guard saving.insert(project.id).inserted else { throw RecoveryMaintenanceError.workspaceBusy }
        defer { saving.remove(project.id) }
        let previous = reports[project.id]
        let metadata = try await images?.upload(project: project, previous: previous) ?? []
        try checkSession()
        let content = try CloudReportContent(project: project, images: metadata)
        let revision = previous?.revision ?? 0
        let saved: CloudReport
        do { saved = try await client.save(id: project.id, revision: revision, content: content) }
        catch CloudTransferError.conflict {
            let remote = try await client.get(id: project.id)
            try checkSession()
            guard revision < Int64.max, remote.revision == revision + 1, remote.report == content else {
                throw CloudTransferError.conflict
            }
            saved = remote
        }
        try checkSession()
        guard saved.id == project.id, saved.revision == revision + 1 else { throw CloudTransferError.invalidResponse }
        _ = try mapped(saved)
        reports[project.id] = saved
        do { try await files.save(project) }
        catch { loadWarnings = ["Saved to cloud, but the local cache could not be updated."] }
    }

    func delete(_ project: ProjectReport) async throws {
        try checkSession()
        guard saving.insert(project.id).inserted else { throw RecoveryMaintenanceError.workspaceBusy }
        defer { saving.remove(project.id) }
        // Browser deletions must use the version shown to the user, captured by listing.
        guard let report = listed[project.id] ?? reports[project.id] else { throw CloudTransferError.conflict }
        try await client.delete(id: project.id, revision: report.revision)
        try checkSession()
        reports[project.id] = nil
    }

    func duplicate(id: UUID, codeName: String) async throws -> ProjectReport {
        guard let original = try await fetchProject(id: id) else { throw CloudTransferError.notFound }
        var source = original
        source.codeName = codeName
        return try await saveCopy(source)
    }

    func saveCopy(_ original: ProjectReport) async throws -> ProjectReport {
        try checkSession()
        let sourceID = original.id
        let copy = ProjectReport(id: UUID(), codeName: original.codeName, lineOfBusiness: original.lineOfBusiness,
            status: original.status, projectSize: original.projectSize, card: original.card, createdAt: .now, updatedAt: .now)
        try await images?.copyCachedImages(from: sourceID, to: copy)
        try await save(copy)
        return copy
    }

    private func mapped(_ report: CloudReport) throws -> ProjectReport {
        guard (1...2).contains(report.schemaVersion), report.revision > 0 else { throw CloudTransferError.invalidResponse }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: report.updatedAt) ?? ISO8601DateFormatter().date(from: report.updatedAt)
        guard let date else { throw CloudTransferError.invalidResponse }
        return try report.report.project(id: report.id, updatedAt: date)
    }
}

@MainActor
protocol CloudProjectImages {
    func upload(project: ProjectReport, previous: CloudReport?) async throws -> [CloudImageAsset]
    func cache(report: CloudReport, project: ProjectReport) async throws
    func copyCachedImages(from id: UUID, to project: ProjectReport) async throws
}
