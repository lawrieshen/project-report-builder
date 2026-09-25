import Foundation
import Testing
@testable import Project_Report_Builder

actor AssetTestRepository: AssetRepository {
    var removed: [String] = []
    var failImport = false
    func setFailImport() { failImport = true }
    func importImage(from url: URL) async throws -> ImageAsset {
        if failImport { throw AssetError.unreadableImage }
        let id = UUID()
        return ImageAsset(id: id, fileName: url.lastPathComponent, localReference: id.uuidString)
    }
    func removeImage(_ asset: ImageAsset) async throws { removed.append(asset.localReference) }
    func thumbnailData(for asset: ImageAsset, maximumPixelSize: Int) async throws -> Data { Data() }
}

@MainActor
struct ReportAssetTests {
    @Test func saveDiscardReplacementAndFailurePreserveFiles() async throws {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                    status: .draft, createdAt: .now, updatedAt: .now)
        let repository = WorkspaceTestRepository(project: project)
        let assets = AssetTestRepository()
        let model = ReportEditorViewModel(projectID: project.id, repository: repository, assetRepository: assets)
        await model.load()
        await model.importImages(from: [URL(fileURLWithPath: "/first.png")])
        let first = try #require(model.draft?.assets.first)
        #expect(model.draft?.assets.count == 1)
        #expect(model.isDirty)
        model.updateAltText(assetID: first.id, altText: "Diagram")
        #expect(await model.save())
        #expect(repository.project?.card?.assets.first?.altText == "Diagram")
        await model.importImages(from: [URL(fileURLWithPath: "/second.png")], replacing: first.id)
        let replacement = try #require(model.draft?.assets.first)
        #expect(replacement.id == first.id)
        #expect(replacement.altText == "Diagram")
        #expect(replacement.localReference != first.localReference)
        repository.failSave = true
        #expect(await model.save() == false)
        await model.cleanupTask?.value
        #expect(await assets.removed.isEmpty)
        await model.discardChanges()
        await model.cleanupTask?.value
        #expect(model.draft?.assets.first?.localReference == first.localReference)
        #expect(await assets.removed.contains(replacement.localReference))
        #expect(await !assets.removed.contains(first.localReference))
        await assets.setFailImport()
        await model.importImages(from: [URL(fileURLWithPath: "/bad.png")], replacing: first.id)
        #expect(model.draft?.assets.first?.localReference == first.localReference)
        #expect(model.assetError != nil)
        model.removeAsset(id: first.id)
        #expect(model.isDirty)
        repository.failSave = false
        #expect(await model.save())
        await model.cleanupTask?.value
        #expect(await assets.removed.contains(first.localReference))
        #expect(repository.project?.card?.assets.isEmpty == true)
    }

    @Test func assetsUseIdentityAndPreserveOrder() async throws {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                    status: .draft, createdAt: .now, updatedAt: .now)
        let assets = AssetTestRepository()
        let model = ReportEditorViewModel(projectID: project.id,
                                         repository: WorkspaceTestRepository(project: project), assetRepository: assets)
        await model.load()
        await model.importImages(from: [URL(fileURLWithPath: "/same.png"), URL(fileURLWithPath: "/same.png")])
        let original = try #require(model.draft?.assets)
        #expect(original.count == 2)
        model.updateAltText(assetID: original[1].id, altText: "Second")
        #expect(model.draft?.assets[0].altText == "")
        model.moveAsset(id: original[1].id, offset: -1)
        #expect(model.draft?.assets.first?.id == original[1].id)
        model.removeAsset(id: original[0].id)
        #expect(model.draft?.assets.count == 1)
        await model.discardChanges()
        await model.cleanupTask?.value
        #expect(model.draft?.assets.isEmpty == true)
        #expect(!model.isDirty)
        #expect(Set(await assets.removed) == Set(original.map(\.localReference)))
    }
}

actor DelayedAssetRepository: AssetRepository {
    private var continuation: CheckedContinuation<ImageAsset, Never>?
    private(set) var removed: [ImageAsset] = []
    var started: Bool { continuation != nil }
    func importImage(from url: URL) async throws -> ImageAsset {
        await withCheckedContinuation { continuation = $0 }
    }
    func finish(with asset: ImageAsset) { continuation?.resume(returning: asset); continuation = nil }
    func removeImage(_ asset: ImageAsset) async throws { removed.append(asset) }
    func thumbnailData(for asset: ImageAsset, maximumPixelSize: Int) async throws -> Data { Data() }
}

@MainActor
struct AssetImportCancellationTests {
    @Test func discardDuringImportDoesNotRestoreAbandonedAssets() async throws {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                    status: .draft, createdAt: .now, updatedAt: .now)
        let assets = DelayedAssetRepository()
        let model = ReportEditorViewModel(projectID: project.id,
                                         repository: WorkspaceTestRepository(project: project), assetRepository: assets)
        await model.load()
        let task = Task { await model.importImages(from: [URL(fileURLWithPath: "/late.png")]) }
        while !(await assets.started) { await Task.yield() }
        #expect(model.isImporting)
        #expect(await model.save() == false)
        await model.discardChanges()
        let abandoned = ImageAsset(id: UUID(), fileName: "late.png", localReference: "late.png")
        await assets.finish(with: abandoned)
        await task.value
        await model.cleanupTask?.value
        #expect(model.draft?.assets.isEmpty == true)
        #expect(!model.isDirty)
        #expect(await assets.removed == [abandoned])
    }
}
