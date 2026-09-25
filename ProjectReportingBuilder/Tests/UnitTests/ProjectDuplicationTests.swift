import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct ProjectDuplicationTests {
    @Test func deepCopyHasIndependentFilesAndRollsBackFailure() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ApplicationStorage(root: root)
        let store = ProjectFileStore(storage: storage)
        var project = ProjectReport(id: UUID(), codeName: "Original", lineOfBusiness: "Camera", status: .active, createdAt: .now, updatedAt: .now)
        try await store.save(project)
        let asset = ImageAsset(id: UUID(), fileName: "photo.png", localReference: UUID().uuidString + ".png", altText: "Red sample")
        try await store.writeAsset(Data([1, 2, 3]), asset: asset, projectID: project.id)
        project.card = SnippetCard(id: UUID(), health: ProjectHealth(ragStatus: .green, milestone: nil),
            summary: ExecutiveSummary(type: .update, message: "Summary"),
            accountability: Accountability(leadEPM: Person(id: UUID(), name: "Jane", role: nil), projectDRI: nil),
            assets: [asset], metrics: [EngineeringMetric(id: UUID(), name: "Bugs", currentValue: 2)])
        try await store.save(project)
        let copy = try await store.duplicate(id: project.id, codeName: "Copy")
        #expect(copy.id != project.id)
        #expect(copy.card?.id != project.card?.id)
        #expect(copy.card?.metrics.first?.id != project.card?.metrics.first?.id)
        #expect(copy.card?.accountability.leadEPM?.id != project.card?.accountability.leadEPM?.id)
        let copiedAsset = try #require(copy.card?.assets.first)
        #expect(copiedAsset.id != asset.id)
        #expect(copiedAsset.altText == asset.altText)
        let copiedURL = try await store.assetURL(copiedAsset, projectID: copy.id)
        #expect(try Data(contentsOf: copiedURL) == Data([1, 2, 3]))
        try await store.delete(id: copy.id)
        #expect(try await store.fetchProject(id: project.id) == project)
        try FileManager.default.removeItem(at: storage.assets(project.id).appendingPathComponent(asset.localReference))
        await #expect(throws: (any Error).self) { try await store.duplicate(id: project.id, codeName: "Broken copy") }
        #expect(try await store.fetchProjects().projects.count == 1)
        #expect(try FileManager.default.contentsOfDirectory(atPath: storage.projects.path).allSatisfy { !$0.hasPrefix(".copy-") })
    }
}
