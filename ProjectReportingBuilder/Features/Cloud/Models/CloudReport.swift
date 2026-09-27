import Foundation

struct CloudReport: Codable, Identifiable {
    var reportID: UUID
    var ownerID: String
    var revision: Int64
    var schemaVersion: Int
    var updatedAt: String
    var report: CloudReportContent
    var id: UUID { reportID }
}

/// Map the explicit cloud contract without leaking local paths or recovery data.
struct CloudReportContent: Codable, Equatable {
    var codeName: String
    var lineOfBusiness: String
    var status: ProjectStatus
    var ragStatus: RAGStatus?
    var milestonePhase: String?
    var milestoneDeadline: String?
    var summaryType: SummaryType
    var summaryMessage: String
    var leadEPMName: String
    var projectDRIName: String
    var metrics: [CloudMetric]
    var assets: [CloudImageAsset]?

    init(project: ProjectReport, images: [CloudImageAsset] = []) throws {
        guard images.count == (project.card?.assets.count ?? 0) else { throw CloudTransferError.imagesUnsupported }
        assets = images
        codeName = project.codeName
        lineOfBusiness = project.lineOfBusiness
        status = project.status
        let card = project.card
        ragStatus = card?.health.ragStatus
        milestonePhase = card?.health.milestone?.phase
        milestoneDeadline = card?.health.milestone.map { Self.dateFormatter.string(from: $0.deadline) }
        summaryType = card?.summary.type ?? .update
        summaryMessage = card?.summary.message ?? ""
        leadEPMName = card?.accountability.leadEPM?.name ?? ""
        projectDRIName = card?.accountability.projectDRI?.name ?? ""
        metrics = (card?.metrics ?? []).map(CloudMetric.init)
    }

    /// Import as an independent project so an open local draft is never overwritten.
    func localCopy() throws -> ProjectReport {
        try project(id: UUID(), updatedAt: Date())
    }

    /// Preserve remote identity when opening a cloud report for editing.
    func project(id: UUID, updatedAt: Date) throws -> ProjectReport {
        var milestone: Milestone?
        if let phase = milestonePhase, let date = milestoneDeadline {
            guard let deadline = Self.dateFormatter.date(from: date),
                  Self.dateFormatter.string(from: deadline) == date else { throw CloudTransferError.invalidResponse }
            milestone = Milestone(phase: phase, deadline: deadline)
        } else if milestonePhase != nil || milestoneDeadline != nil { throw CloudTransferError.invalidResponse }
        let card = SnippetCard(id: id, health: ProjectHealth(ragStatus: ragStatus, milestone: milestone),
            summary: ExecutiveSummary(type: summaryType, message: summaryMessage),
            accountability: Accountability(leadEPM: person(leadEPMName), projectDRI: person(projectDRIName)),
            assets: try (assets ?? []).map { try $0.localAsset() },
            metrics: try metrics.map { try $0.localMetric() })
        return ProjectReport(id: id, codeName: codeName, lineOfBusiness: lineOfBusiness, status: status,
                             card: card, createdAt: updatedAt, updatedAt: updatedAt)
    }

    private func person(_ name: String) -> Person? {
        name.isEmpty ? nil : Person(id: UUID(), name: name, role: nil)
    }

    private static var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }

    enum CodingKeys: String, CodingKey {
        case codeName, lineOfBusiness, status, ragStatus, milestonePhase, milestoneDeadline
        case summaryType, summaryMessage, leadEPMName, projectDRIName, metrics, assets
    }

    // The API requires nullable fields to be present, so encode nil as JSON null.
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(codeName, forKey: .codeName)
        try values.encode(lineOfBusiness, forKey: .lineOfBusiness)
        try values.encode(status, forKey: .status)
        try values.encode(ragStatus, forKey: .ragStatus)
        try values.encode(milestonePhase, forKey: .milestonePhase)
        try values.encode(milestoneDeadline, forKey: .milestoneDeadline)
        try values.encode(summaryType, forKey: .summaryType)
        try values.encode(summaryMessage, forKey: .summaryMessage)
        try values.encode(leadEPMName, forKey: .leadEPMName)
        try values.encode(projectDRIName, forKey: .projectDRIName)
        try values.encode(metrics, forKey: .metrics)
        try values.encode(assets ?? [], forKey: .assets)
    }
}

struct CloudMetric: Codable, Equatable {
    var id: String
    var name: String
    var currentValue: Double
    var targetValue: Double?
    var comparison: String?
    var unit: String?
    var severity: String?

    init(_ metric: EngineeringMetric) {
        id = metric.id.uuidString.lowercased()
        name = metric.name
        currentValue = metric.currentValue
        targetValue = metric.target?.value
        comparison = metric.target.map { target in
            switch target.comparison {
            case .lessThan: "lt"
            case .lessThanOrEqual: "lte"
            case .greaterThan: "gt"
            case .greaterThanOrEqual: "gte"
            case .equal: "eq"
            }
        }
        unit = metric.unit
        severity = metric.severity.map { $0 == .info ? "Info" : $0.rawValue.uppercased() }
    }

    func localMetric() throws -> EngineeringMetric {
        guard let id = UUID(uuidString: id), currentValue.isFinite else { throw CloudTransferError.invalidResponse }
        var target: MetricTarget?
        if let targetValue, let comparison {
            let operation: MetricComparison
            switch comparison {
            case "lt": operation = .lessThan
            case "lte": operation = .lessThanOrEqual
            case "gt": operation = .greaterThan
            case "gte": operation = .greaterThanOrEqual
            case "eq": operation = .equal
            default: throw CloudTransferError.invalidResponse
            }
            guard targetValue.isFinite else { throw CloudTransferError.invalidResponse }
            target = MetricTarget(value: targetValue, comparison: operation)
        } else if targetValue != nil || comparison != nil { throw CloudTransferError.invalidResponse }
        let level = severity.flatMap { MetricSeverity(rawValue: $0.lowercased()) }
        guard severity == nil || level != nil else { throw CloudTransferError.invalidResponse }
        return EngineeringMetric(id: id, name: name, currentValue: currentValue, target: target, unit: unit, severity: level)
    }

    enum CodingKeys: String, CodingKey { case id, name, currentValue, targetValue, comparison, unit, severity }
    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(name, forKey: .name)
        try values.encode(currentValue, forKey: .currentValue)
        try values.encode(targetValue, forKey: .targetValue)
        try values.encode(comparison, forKey: .comparison)
        try values.encode(unit, forKey: .unit)
        try values.encode(severity, forKey: .severity)
    }
}

enum CloudTransferError: LocalizedError {
    case notFound, imagesUnsupported, invalidResponse, conflict, signedOut, rejected, missingProject, serverUnavailable, forbidden, imageLimit, imageTransferFailed
    var errorDescription: String? {
        switch self {
        case .notFound: "This cloud report no longer exists."
        case .imageLimit: "Use at most 10 images, 20 MB each and 50 MB total per report."
        case .imageTransferFailed: "Image transfer failed. Retry to complete the report; your local original is unchanged."
        case .imagesUnsupported: "Image uploads are unavailable in this configuration. This report was not uploaded."
        case .invalidResponse: "The cloud service returned an invalid report."
        case .conflict: "The cloud report has changed. Download a copy to compare; your local report is unchanged."
        case .signedOut: "Please sign in again to access cloud reports."
        case .serverUnavailable: "The cloud service is temporarily unavailable. Your local reports are unchanged. Please retry later."
        case .forbidden: "This account does not have permission to access cloud reports."
        case .rejected: "The cloud service rejected this request. Check your report fields and account access."
        case .missingProject: "This local project is no longer available. Refresh the list."
        }
    }
}
