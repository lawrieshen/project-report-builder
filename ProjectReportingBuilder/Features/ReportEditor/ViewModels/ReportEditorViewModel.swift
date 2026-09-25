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

    init(projectID: UUID, repository: ProjectRepository) {
        self.projectID = projectID
        self.repository = repository
    }

    var isDirty: Bool { draft != savedDraft }
    var canSave: Bool { isDirty && draft?.isValid == true && !isLoading && !isSaving }

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
        guard !isLoading, !isSaving, let project, let submittedDraft = draft else { return false }
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
            self.project = updated
            savedDraft = ReportEditorDraft(project: updated)
            // Preserve any newer edits made while the save was awaiting completion.
            if draft == submittedDraft {
                draft = savedDraft
            }
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
        draft = savedDraft
        saveError = nil
    }

    func retry() async {
        await load()
    }
}
