import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct DraftRecoveryRepositoryTests {
    @Test func recoveryPreservesRawInputWithoutChangingCanonicalData() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ApplicationStorage(root: root)
        let store = ProjectFileStore(storage: storage)
        var project = ProjectReport(id: UUID(), codeName: "Saved", lineOfBusiness: "iPhone", status: .draft, createdAt: .now, updatedAt: .now)
        try await store.save(project)
        var draft = ReportEditorDraft(project: project)
        draft.codeName = ""
        var metric = EngineeringMetricDraft()
        metric.currentValueText = "unfinished-"
        draft.metrics = [metric]
        let asset = ImageAsset(id: UUID(), fileName: "photo.png", localReference: UUID().uuidString + ".png")
        try await store.writeAsset(Data([1, 2, 3]), asset: asset, projectID: project.id)
        draft.assets = [asset]
        let snapshot = RecoverySnapshot(projectID: project.id, baseUpdatedAt: project.updatedAt, capturedAt: .now, draft: draft)
        try await store.saveRecovery(snapshot)
        let reopened = ProjectFileStore(storage: storage)
        #expect(try await reopened.fetchProject(id: project.id) == project)
        #expect(try await reopened.fetchRecovery(projectID: project.id) == snapshot)
        try await reopened.removeAsset(asset, projectID: project.id)
        #expect(FileManager.default.fileExists(atPath: storage.assets(project.id).appendingPathComponent(asset.localReference).path))
        project.updatedAt = project.updatedAt.addingTimeInterval(1)
        try await reopened.save(project)
        #expect(try await reopened.fetchRecovery(projectID: project.id) == nil)
        try await reopened.deleteRecovery(projectID: project.id)
        try await reopened.saveRecovery(snapshot)
        #expect(!FileManager.default.fileExists(atPath: storage.recoveryFile(project.id).path))
    }
}
