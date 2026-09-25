import Foundation

/// Keep editable values separate from the saved report.
struct ReportEditorDraft: Equatable {
    var codeName: String
    var lineOfBusiness: String
    var ragStatus: RAGStatus?
    var milestonePhase: String
    var milestoneDeadline: Date?
    var metrics: [EngineeringMetricDraft]
    var summaryType: SummaryType
    var summaryMessage: String
    var leadEPMName: String
    var projectDRIName: String

    init(project: ProjectReport) {
        codeName = project.codeName
        lineOfBusiness = project.lineOfBusiness
        ragStatus = project.card?.health.ragStatus
        milestonePhase = project.card?.health.milestone?.phase ?? ""
        milestoneDeadline = project.card?.health.milestone?.deadline
        metrics = project.card?.metrics.map { EngineeringMetricDraft(metric: $0) } ?? []
        summaryType = project.card?.summary.type ?? .update
        summaryMessage = project.card?.summary.message ?? ""
        leadEPMName = project.card?.accountability.leadEPM?.name ?? ""
        projectDRIName = project.card?.accountability.projectDRI?.name ?? ""
    }

    var codeNameError: String? {
        trimmed(codeName).isEmpty ? "Enter a project code name." : nil
    }

    var lineOfBusinessError: String? {
        trimmed(lineOfBusiness).isEmpty ? "Enter a line of business." : nil
    }

    var milestoneError: String? {
        let hasPhase = !trimmed(milestonePhase).isEmpty
        let hasDeadline = milestoneDeadline != nil
        return hasPhase == hasDeadline ? nil : "Provide both a milestone phase and deadline, or clear both."
    }

    var metricsError: String? {
        for metric in metrics {
            if let error = metric.validationError(in: metrics) { return error }
        }
        return nil
    }

    var isValid: Bool {
        codeNameError == nil && lineOfBusinessError == nil && milestoneError == nil && metricsError == nil
    }

    /// Apply editable fields while preserving identity, template, status, and metadata.
    /// - Returns: A report ready to save. Validate the draft before calling.
    /// - Throws: A validation error if a metric cannot be converted.
    func applying(to project: ProjectReport, cardID: UUID, updatedAt: Date) throws -> ProjectReport {
        if let metricsError { throw MetricValidationError(message: metricsError) }
        var result = project
        result.codeName = trimmed(codeName)
        result.lineOfBusiness = trimmed(lineOfBusiness)
        result.updatedAt = updatedAt
        var milestone: Milestone?
        if let deadline = milestoneDeadline, !trimmed(milestonePhase).isEmpty {
            milestone = Milestone(phase: trimmed(milestonePhase), deadline: deadline)
        }
        result.card = SnippetCard(
            id: project.card?.id ?? cardID,
            health: ProjectHealth(ragStatus: ragStatus, milestone: milestone),
            summary: ExecutiveSummary(type: summaryType, message: summaryMessage),
            accountability: Accountability(
                leadEPM: person(named: leadEPMName, existing: project.card?.accountability.leadEPM),
                projectDRI: person(named: projectDRIName, existing: project.card?.accountability.projectDRI)
            ),
            metrics: try metrics.map { try $0.makeMetric() }
        )
        return result
    }

    private func person(named name: String, existing: Person?) -> Person? {
        let name = trimmed(name)
        guard !name.isEmpty else { return nil }
        if var existing {
            existing.name = name
            return existing
        }
        return Person(id: UUID(), name: name, role: nil)
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
