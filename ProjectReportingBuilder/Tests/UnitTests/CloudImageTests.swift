import AppKit
import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct CloudImageTests {
    private func png() throws -> Data {
        let bitmap = try #require(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for x in 0..<2 { for y in 0..<2 { bitmap.setColor(.blue, atX: x, y: y) } }
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    @Test func metadataPreservesIdentityAndRejectsCorruption() throws {
        let data = try png()
        let asset = ImageAsset(id: UUID(), fileName: "diagram.png", localReference: "original.png", altText: "Blue diagram")
        let metadata = try CloudImageAsset(asset: asset, data: data)
        try metadata.validate(data)
        let local = try metadata.localAsset()
        #expect(local.id == asset.id)
        #expect(local.altText == asset.altText)
        #expect(local.localReference != asset.localReference)
        var corrupt = data
        corrupt[0] = 0
        #expect(throws: (any Error).self) { try metadata.validate(corrupt) }
        var unsafe = metadata
        unsafe.fileName = "../diagram.png"
        #expect(throws: (any Error).self) { try unsafe.validateMetadata() }
    }

    @Test func unchangedImagesUseCacheWithoutNetworkRequests() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let files = ProjectFileStore(storage: ApplicationStorage(root: root))
        let data = try png()
        let asset = ImageAsset(id: UUID(), fileName: "image.png", localReference: "image.png", altText: "Blue")
        let metadata = try CloudImageAsset(asset: asset, data: data)
        let local = try metadata.localAsset()
        let project = ProjectReport(id: UUID(), codeName: "Test", lineOfBusiness: "Mac", status: .draft,
            card: SnippetCard(id: UUID(), health: ProjectHealth(ragStatus: nil, milestone: nil),
                summary: ExecutiveSummary(type: .update, message: ""),
                accountability: Accountability(leadEPM: nil, projectDRI: nil), assets: [local]),
            createdAt: .now, updatedAt: .now)
        try await files.save(project)
        try await files.writeAsset(data, asset: local, projectID: project.id)
        let report = CloudReport(reportID: project.id, ownerID: "test", revision: 1, schemaVersion: 2,
            updatedAt: "2026-09-27T00:00:00Z", report: try CloudReportContent(project: project, images: [metadata]))
        let images = CloudImageTransfer(files: files, client: NoImageRequests())
        #expect(try await images.upload(project: project, previous: report) == [metadata])
        try await images.cache(report: report, project: project)
    }

    @Test func importPublishesAllAssetsOrNothing() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ApplicationStorage(root: root)
        let files = ProjectFileStore(storage: storage)
        let data = try png()
        let asset = ImageAsset(id: UUID(), fileName: "diagram.png", localReference: "diagram.png", altText: "Diagram")
        let project = ProjectReport(id: UUID(), codeName: "Cloud", lineOfBusiness: "Mac", status: .draft,
            card: SnippetCard(id: UUID(), health: ProjectHealth(ragStatus: .green, milestone: nil),
                summary: ExecutiveSummary(type: .update, message: ""),
                accountability: Accountability(leadEPM: nil, projectDRI: nil), assets: [asset], metrics: []),
            createdAt: .now, updatedAt: .now)
        do {
            try await files.importCloudCopy(project, images: [:])
            Issue.record("Missing image should fail")
        } catch {
            #expect(!FileManager.default.fileExists(atPath: storage.projectDirectory(project.id).path))
            #expect(try FileManager.default.contentsOfDirectory(atPath: storage.projects.path).isEmpty)
        }
        try await files.importCloudCopy(project, images: [asset.id: data])
        #expect(try await files.fetchProject(id: project.id) == project)
        #expect(try await files.cloudImageData(asset, projectID: project.id) == data)
    }
}

@MainActor
private struct NoImageRequests: CloudImageURLServing {
    func uploadURL(projectID: UUID, asset: CloudImageAsset) async throws -> CloudAssetTransfer {
        Issue.record("Unchanged bytes must not be uploaded again")
        throw CloudTransferError.rejected
    }
    func downloadURL(projectID: UUID, assetID: String) async throws -> CloudAssetTransfer {
        Issue.record("Valid cached bytes must not be downloaded again")
        throw CloudTransferError.rejected
    }
}
