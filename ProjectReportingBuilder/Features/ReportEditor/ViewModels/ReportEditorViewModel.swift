import Foundation
import Observation

@MainActor
@Observable
final class ReportEditorViewModel {
    let projectID: UUID
    private(set) var project: ProjectReport?
    var draft: ReportEditorDraft?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var loadError: String?
    private(set) var saveError: String?
    private(set) var hasLoaded = false
    private var savedDraft: ReportEditorDraft?
    private let repository: ProjectRepository
    private let assetRepository: any AssetRepository
    private var importedAssets: [ImageAsset] = []
    private var assetGeneration = 0
    private(set) var isImporting = false
    var assetError: String?
    private(set) var cleanupWarning: String?
    private(set) var cleanupTask: Task<Void, Never>?


    init(projectID: UUID, repository: ProjectRepository,
         assetRepository: any AssetRepository = LocalAssetRepository()) {
        self.projectID = projectID
        self.repository = repository
        self.assetRepository = assetRepository
    }

    var isDirty: Bool { draft != savedDraft }
    var canSave: Bool { isDirty && draft?.isValid == true && !isLoading && !isSaving && !isImporting }

    /// Load once without overwriting edits when the view reappears.
    func load() async {
        guard !isLoading, !isSaving, !hasLoaded else { return }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            var loaded = try await repository.fetchProject(id: projectID)
            try Task.checkCancellation()
            if loaded != nil && loaded?.card == nil {
                loaded?.card = SnippetCard(
                    id: UUID(),
                    health: ProjectHealth(ragStatus: nil, milestone: nil),
                    summary: ExecutiveSummary(type: .update, message: ""),
                    accountability: Accountability(leadEPM: nil, projectDRI: nil)
                )
            }
            project = loaded
            draft = loaded.map { ReportEditorDraft(project: $0) }
            savedDraft = draft
            hasLoaded = true
        } catch is CancellationError {
            // A cancelled load can be retried when the view reappears.
        } catch {
            loadError = error.localizedDescription
        }
    }

    /// Save a validated snapshot; keep edits intact if the repository fails.
    /// - Returns: Whether saving succeeded, or the loaded report was already clean.
    func save() async -> Bool {
        guard !isLoading, !isSaving, !isImporting, let project, let submittedDraft = draft else { return false }
        guard submittedDraft.isValid else {
            saveError = "Correct the highlighted fields before saving."
            return false
        }
        guard isDirty else { return true }
        isSaving = true
        saveError = nil
        defer { isSaving = false }
        do {
            let updated = try submittedDraft.applying(to: project, cardID: project.card?.id ?? UUID(), updatedAt: .now)
            try await repository.save(updated)
            let previousAssets = savedDraft?.assets ?? []
            self.project = updated
            savedDraft = ReportEditorDraft(project: updated)
            // Preserve any newer edits made while the save was awaiting completion.
            if draft == submittedDraft {
                draft = savedDraft
            }
            cleanUnusedAssets(previousAssets + importedAssets)
            importedAssets = []
            return true
        } catch {
            saveError = error.localizedDescription
            return false
        }
    }

    /// Add a confirmed metric without writing to the repository.
    /// - Returns: A validation message, or nil on success.
    func addMetric(_ metric: EngineeringMetricDraft) -> String? {
        guard !isSaving, !isLoading, var draft else { return "The report is busy. Try again." }
        guard !draft.metrics.contains(where: { $0.id == metric.id }) else { return "This metric already exists." }
        if let message = metric.validationError(in: draft.metrics) { return message }
        draft.metrics.append(metric)
        self.draft = draft
        return nil
    }

    /// Replace a metric by ID while preserving its position in the report.
    func updateMetric(_ metric: EngineeringMetricDraft) -> String? {
        guard !isSaving, !isLoading, var draft else { return "The report is busy. Try again." }
        guard let index = draft.metrics.firstIndex(where: { $0.id == metric.id }) else {
            return "This metric no longer exists."
        }
        if let message = metric.validationError(in: draft.metrics) { return message }
        draft.metrics[index] = metric
        self.draft = draft
        return nil
    }

    func deleteMetric(id: UUID) {
        guard !isSaving, !isLoading else { return }
        draft?.metrics.removeAll { $0.id == id }
    }

    /// Move metrics using array insertion offsets; array order is the saved order.
    func moveMetric(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        guard !isSaving, !isLoading, var draft,
              destination >= 0, destination <= draft.metrics.count,
              offsets.allSatisfy({ draft.metrics.indices.contains($0) }) else { return }
        let moved = offsets.sorted().map { draft.metrics[$0] }
        let insertion = destination - offsets.filter { $0 < destination }.count
        for index in offsets.sorted(by: >) { draft.metrics.remove(at: index) }
        draft.metrics.insert(contentsOf: moved, at: insertion)
        self.draft = draft
    }

    func discardChanges() {
        guard !isSaving else { return }
        assetGeneration += 1
        draft = savedDraft
        saveError = nil
        assetError = nil
        cleanUnusedAssets(importedAssets)
        importedAssets = []
    }

    /// Import or replace an image only after the managed copy has been validated.
    func importImages(from urls: [URL], replacing assetID: UUID? = nil) async {
        guard !isLoading, !isSaving, !isImporting, draft != nil else { return }
        if assetID != nil && urls.count != 1 { return }
        isImporting = true
        assetError = nil
        let generation = assetGeneration
        defer { isImporting = false }
        var failures: [String] = []
        for url in urls {
            do {
                let imported = try await assetRepository.importImage(from: url)
                guard generation == assetGeneration, !Task.isCancelled, var current = draft else {
                    cleanUnusedAssets([imported])
                    return
                }
                if let assetID {
                    guard let index = current.assets.firstIndex(where: { $0.id == assetID }) else {
                        cleanUnusedAssets([imported])
                        return
                    }
                    let old = current.assets[index]
                    // Preserve the logical asset identity, alt text, and array position.
                    current.assets[index] = ImageAsset(id: old.id, fileName: imported.fileName,
                                                       localReference: imported.localReference, altText: old.altText)
                } else {
                    current.assets.append(imported)
                }
                importedAssets.append(imported)
                draft = current
                cleanUnusedAssets(importedAssets)
            } catch is CancellationError {
                return
            } catch {
                failures.append(url.lastPathComponent + ": " + error.localizedDescription)
            }
        }
        if !failures.isEmpty { assetError = failures.joined(separator: "\n") }
    }

    func removeAsset(id: UUID) {
        guard !isSaving, !isImporting else { return }
        draft?.assets.removeAll { $0.id == id }
        cleanUnusedAssets(importedAssets)
    }

    func updateAltText(assetID: UUID, altText: String) {
        guard !isSaving, let index = draft?.assets.firstIndex(where: { $0.id == assetID }) else { return }
        draft?.assets[index].altText = altText
    }

    func moveAsset(id: UUID, offset: Int) {
        guard !isSaving, !isImporting, var current = draft,
              let index = current.assets.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard current.assets.indices.contains(destination) else { return }
        current.assets.swapAt(index, destination)
        draft = current
    }

    func imageData(for asset: ImageAsset, maximumPixelSize: Int = 320) async throws -> Data {
        try await assetRepository.thumbnailData(for: asset, maximumPixelSize: maximumPixelSize)
    }

    /// Delete only files unreferenced by both the saved report and the current draft.
    private func cleanUnusedAssets(_ candidates: [ImageAsset]) {
        let retained = Set((draft?.assets ?? []).map(\.localReference)
                           + (savedDraft?.assets ?? []).map(\.localReference))
        let unused = candidates.filter { !retained.contains($0.localReference) }
        let previousTask = cleanupTask
        cleanupTask = Task {
            await previousTask?.value
            for asset in unused {
                do {
                    try await assetRepository.removeImage(asset)
                } catch {
                    cleanupWarning = "Some unused image files could not be removed: " + error.localizedDescription
                }
            }
        }
    }

    func retry() async {
        await load()
    }
}
