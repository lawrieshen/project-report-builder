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

    private func makeImage(in directory: URL, type: UTType) throws -> URL {
        let context = try #require(CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8,
                                            bytesPerRow: 32, space: CGColorSpaceCreateDeviceRGB(),
                                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        let image = try #require(context.makeImage())
        let url = directory.appendingPathComponent("sample." + (type.preferredFilenameExtension ?? "image"))
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }
}
