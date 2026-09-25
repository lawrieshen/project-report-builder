import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import Project_Report_Builder

struct AssetRepositoryTests {
    @Test func supportedImagesAreCopiedWithUniqueReferences() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let repository = LocalAssetRepository(directory: root.appendingPathComponent("managed"))
        for type in [UTType.png, .jpeg, .heic] {
            let source = try makeImage(in: root, type: type)
            let first = try await repository.importImage(from: source)
            let second = try await repository.importImage(from: source)
            #expect(first.id != second.id)
            #expect(first.localReference != second.localReference)
            #expect(first.fileName == second.fileName)
            try FileManager.default.removeItem(at: source)
            let thumbnail = try await repository.thumbnailData(for: first, maximumPixelSize: 100)
            #expect(!thumbnail.isEmpty)
            try await repository.removeImage(first)
            let secondThumbnail = try await repository.thumbnailData(for: second, maximumPixelSize: 100)
            #expect(!secondThumbnail.isEmpty)
        }
    }

    @MainActor
    @Test func thumbnailsKeepDistinctContentWhenSourceFilenameIsReused() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let repository = LocalAssetRepository(directory: root.appendingPathComponent("managed"))
        let source = try makeImage(in: root, type: .png, red: 0.1, green: 0.3, blue: 0.9)
        let original = try await repository.importImage(from: source)
        // Overwrite the source with orange pixels but retain the same filename.
        _ = try makeImage(in: root, type: .png, red: 0.95, green: 0.5, blue: 0.05)
        let replacement = try await repository.importImage(from: source)
        try FileManager.default.removeItem(at: source)
        #expect(original.fileName == replacement.fileName)
        #expect(original.localReference != replacement.localReference)

        let originalData = try await repository.thumbnailData(for: original, maximumPixelSize: 4)
        let replacementData = try await repository.thumbnailData(for: replacement, maximumPixelSize: 4)
        try expectColor(in: originalData, red: 0.1, green: 0.3, blue: 0.9)
        try expectColor(in: replacementData, red: 0.95, green: 0.5, blue: 0.05)
        try await repository.removeImage(replacement)
        let retainedData = try await repository.thumbnailData(for: original, maximumPixelSize: 4)
        try expectColor(in: retainedData, red: 0.1, green: 0.3, blue: 0.9)
    }

    @MainActor
    private func expectColor(in data: Data, red: CGFloat, green: CGFloat, blue: CGFloat) throws {
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 4)
        #expect(image.height == 4)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        var pixel = [UInt8](repeating: 0, count: 4)
        try pixel.withUnsafeMutableBytes { bytes in
            let context = try #require(CGContext(
                data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                bytesPerRow: 4, space: colorSpace,
                bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        #expect(abs(CGFloat(pixel[0]) / 255 - red) < 0.04)
        #expect(abs(CGFloat(pixel[1]) / 255 - green) < 0.04)
        #expect(abs(CGFloat(pixel[2]) / 255 - blue) < 0.04)
    }

    @Test func invalidOversizedAndEscapingFilesAreRejected() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let repository = LocalAssetRepository(directory: root.appendingPathComponent("managed"))
        let gif = try makeImage(in: root, type: .gif)
        await #expect(throws: (any Error).self) { try await repository.importImage(from: gif) }
        let fake = root.appendingPathComponent("fake.png")
        try Data("not an image".utf8).write(to: fake)
        await #expect(throws: (any Error).self) { try await repository.importImage(from: fake) }
        let limited = LocalAssetRepository(directory: root.appendingPathComponent("limited"), maximumFileSize: 1)
        let png = try makeImage(in: root, type: .png)
        await #expect(throws: (any Error).self) { try await limited.importImage(from: png) }
        let outside = ImageAsset(id: UUID(), fileName: "fake", localReference: "../fake.png")
        await #expect(throws: (any Error).self) { try await repository.removeImage(outside) }
        #expect(FileManager.default.fileExists(atPath: fake.path))
    }

    @Test func persistentAssetsSurviveReopeningAndSourceRemoval() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ApplicationStorage(root: root)
        try storage.prepare()
        let store = ProjectFileStore(storage: storage)
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera", status: .draft, createdAt: .now, updatedAt: .now)
        try await store.save(project)
        let source = try makeImage(in: root, type: .png)
        let assets = LocalAssetRepository(storage: storage, projectID: project.id, store: store)
        let asset = try await assets.importImage(from: source)
        try FileManager.default.removeItem(at: source)
        let reopened = LocalAssetRepository(storage: storage, projectID: project.id, store: ProjectFileStore(storage: storage))
        #expect(try await reopened.thumbnailData(for: asset, maximumPixelSize: 8).isEmpty == false)
        #expect(!asset.localReference.contains("/"))
        try await store.delete(id: project.id)
        await #expect(throws: (any Error).self) { try await store.writeAsset(Data(), asset: asset, projectID: project.id) }
        #expect(!FileManager.default.fileExists(atPath: storage.projectDirectory(project.id).path))
    }

    private func makeImage(in directory: URL, type: UTType,
                           red: CGFloat = 0.1, green: CGFloat = 0.3, blue: CGFloat = 0.9) throws -> URL {
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8,
                                            bytesPerRow: 32, space: colorSpace,
                                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let color = try #require(CGColor(colorSpace: colorSpace, components: [red, green, blue, 1]))
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        let image = try #require(context.makeImage())
        let url = directory.appendingPathComponent("sample." + (type.preferredFilenameExtension ?? "image"))
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }
}
