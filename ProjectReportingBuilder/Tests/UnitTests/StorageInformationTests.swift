import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct StorageInformationTests {
    @Test func countsManagedFilesAndRecoversInterruptedDeletion() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ApplicationStorage(root: root)
        let store = ProjectFileStore(storage: storage)
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone", status: .draft, createdAt: .now, updatedAt: .now)
        try await store.save(project)
        let asset = ImageAsset(id: UUID(), fileName: "image.png", localReference: UUID().uuidString + ".png")
        try await store.writeAsset(Data([1, 2, 3]), asset: asset, projectID: project.id)
        let info = try await store.information()
        #expect(info.projectCount == 1)
        #expect(info.assetCount == 1)
        #expect(info.bytes > 3)
        let snapshot = RecoverySnapshot(projectID: project.id, baseUpdatedAt: project.updatedAt,
                                        capturedAt: .now, draft: ReportEditorDraft(project: project))
        try await store.saveRecovery(snapshot)
        let tombstone = storage.projects.appendingPathComponent(".deleted-" + project.id.uuidString)
        try FileManager.default.moveItem(at: storage.projectDirectory(project.id), to: tombstone)
        let restarted = ProjectFileStore(storage: storage)
        #expect(try await restarted.fetchProjects().projects.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: storage.recoveryFile(project.id).path))
        #expect(!FileManager.default.fileExists(atPath: tombstone.path))
    }
}
