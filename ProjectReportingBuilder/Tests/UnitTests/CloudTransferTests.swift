import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct CloudTransferTests {
    private func project() -> ProjectReport {
        ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone", status: .active,
            card: SnippetCard(id: UUID(), health: ProjectHealth(ragStatus: .amber, milestone: nil),
                summary: ExecutiveSummary(type: .update, message: "Ready"),
                accountability: Accountability(leadEPM: nil, projectDRI: nil),
                metrics: [EngineeringMetric(id: UUID(), name: "Bugs", currentValue: 2,
                    target: MetricTarget(value: 3, comparison: .lessThanOrEqual), unit: nil, severity: .p1)]),
            createdAt: .now, updatedAt: .now)
    }

    @Test func payloadUsesExplicitNullsAndBackendMetricNames() throws {
        var source = project()
        source.card?.metrics.append(EngineeringMetric(id: UUID(), name: "Count", currentValue: 10))
        let content = try CloudReportContent(project: source)
        let data = try JSONEncoder().encode(content)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["milestonePhase"] is NSNull)
        #expect(json["milestoneDeadline"] is NSNull)
        let metrics = try #require(json["metrics"] as? [[String: Any]])
        #expect(metrics[0]["comparison"] as? String == "lte")
        #expect(metrics[0]["severity"] as? String == "P1")
        #expect(metrics[1]["targetValue"] is NSNull)
        #expect(metrics[1]["comparison"] is NSNull)
        #expect(metrics[0]["id"] as? String == source.card?.metrics[0].id.uuidString.lowercased())
        let copy = try content.localCopy()
        #expect(copy.id != source.id)
        #expect(copy.card?.metrics == source.card?.metrics)
        #expect(copy.card?.summary == source.card?.summary)
    }

    @Test func missingImageServiceRejectsBeforeCallingCloud() async throws {
        var source = project()
        source.card?.assets = [ImageAsset(id: UUID(), fileName: "a.png", localReference: "a.png")]
        let client = TransferClientStub()
        let store = CloudTransferStore(projects: InMemoryProjectRepository(projects: [source]),
                                       client: client, history: TransferHistoryStub())
        await store.upload(id: source.id)
        #expect(client.saveCount == 0)
        #expect(store.message?.contains("Image uploads") == true)
    }

    @Test func acknowledgementsPersistAcrossHistoryInstances() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: file) }
        let id = UUID()
        try CloudUploadHistory(file: file).record(id: id, revision: 4)
        #expect(try CloudUploadHistory(file: file).revision(for: id) == 4)
        try Data("invalid".utf8).write(to: file)
        #expect(throws: (any Error).self) { try CloudUploadHistory(file: file).revision(for: id) }
    }

    @Test func uploadUsesLastAcknowledgedRevision() async throws {
        let source = project()
        let client = TransferClientStub()
        let history = TransferHistoryStub()
        let store = CloudTransferStore(projects: InMemoryProjectRepository(projects: [source]), client: client, history: history)
        await store.upload(id: source.id)
        await store.upload(id: source.id)
        #expect(client.receivedRevisions == [0, 1])
        #expect(history.value == 2)
    }

    @Test func lostResponseIsReconciledWithoutAnotherWrite() async throws {
        let source = project()
        let client = TransferClientStub()
        client.conflict = true
        client.remote = CloudReport(reportID: source.id, ownerID: "approved", revision: 1, schemaVersion: 1,
                                    updatedAt: "2026-09-27T00:00:00Z", report: try CloudReportContent(project: source))
        let history = TransferHistoryStub()
        let store = CloudTransferStore(projects: InMemoryProjectRepository(projects: [source]), client: client, history: history)
        await store.upload(id: source.id)
        #expect(history.value == 1)
        #expect(store.message == "Uploaded Titan.")
    }

    @Test func conflictDoesNotAcceptDifferentCloudContent() async throws {
        let source = project()
        let client = TransferClientStub()
        client.conflict = true
        var content = try CloudReportContent(project: source)
        content.summaryMessage = "Changed on another device"
        client.remote = CloudReport(reportID: source.id, ownerID: "approved", revision: 1, schemaVersion: 1,
                                    updatedAt: "2026-09-27T00:00:00Z", report: content)
        let history = TransferHistoryStub()
        let store = CloudTransferStore(projects: InMemoryProjectRepository(projects: [source]), client: client, history: history)
        await store.upload(id: source.id)
        #expect(history.value == 0)
        #expect(store.message?.contains("cloud report has changed") == true)
    }

    @Test func downloadLeavesExistingProjectUntouched() async throws {
        let source = project()
        let repository = InMemoryProjectRepository(projects: [source])
        let client = TransferClientStub()
        client.remote = CloudReport(reportID: source.id, ownerID: "approved", revision: 1, schemaVersion: 1,
                                    updatedAt: "2026-09-27T00:00:00Z", report: try CloudReportContent(project: source))
        let store = CloudTransferStore(projects: repository, client: client, history: TransferHistoryStub())
        await store.download(id: source.id)
        #expect(try await repository.fetchProjects().count == 2)
        #expect(try await repository.fetchProject(id: source.id) == source)
    }
}

@MainActor
private final class TransferHistoryStub: CloudUploadTracking {
    var value: Int64 = 0
    func revision(for id: UUID) throws -> Int64 { value }
    func record(id: UUID, revision: Int64) throws { value = revision }
}

@MainActor
private final class TransferClientStub: CloudReportServing {
    var saveCount = 0
    var receivedRevisions: [Int64] = []
    var conflict = false
    var remote: CloudReport?
    func list(after: UUID?) async throws -> CloudReportPage { CloudReportPage(items: [], nextCursor: nil) }
    func get(id: UUID) async throws -> CloudReport {
        guard let remote else { throw CloudTransferError.invalidResponse }
        return remote
    }
    func save(id: UUID, revision: Int64, content: CloudReportContent) async throws -> CloudReport {
        saveCount += 1
        receivedRevisions.append(revision)
        if conflict { throw CloudTransferError.conflict }
        return CloudReport(reportID: id, ownerID: "approved", revision: revision + 1,
                           schemaVersion: 1, updatedAt: "2026-09-27T00:00:00Z", report: content)
    }
}
