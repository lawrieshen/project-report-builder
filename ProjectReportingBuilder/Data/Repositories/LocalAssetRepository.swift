import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Copy images into managed storage and decode bounded thumbnails off the UI thread.
actor LocalAssetRepository: AssetRepository {
    private let directory: URL
    private let maximumFileSize: Int

    // Reports currently live in memory, so the default asset directory is session-scoped.
    init(directory: URL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ProjectReportAssets")
        .appendingPathComponent(UUID().uuidString),
         maximumFileSize: Int = 20 * 1_048_576) {
        self.directory = directory
        self.maximumFileSize = maximumFileSize
    }

    func importImage(from url: URL) async throws -> ImageAsset {
        guard url.isFileURL else { throw AssetError.unreadableImage }
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true, let size = values.fileSize else {
            throw AssetError.unreadableImage
        }
        guard size <= maximumFileSize else { throw AssetError.tooLarge(maximumFileSize) }
        let data = try Data(contentsOf: url)
        guard data.count <= maximumFileSize else { throw AssetError.tooLarge(maximumFileSize) }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let identifier = CGImageSourceGetType(source) else { throw AssetError.unreadableImage }
        let type = UTType(identifier as String)
        guard type == .png || type == .jpeg || type == .heic else { throw AssetError.unsupportedType }
        _ = try thumbnail(source: source, maximumPixelSize: 64)
        try Task.checkCancellation()
        let id = UUID()
        let reference = id.uuidString + "." + (type?.preferredFilenameExtension ?? "image")
        let asset = ImageAsset(id: id, fileName: url.lastPathComponent, localReference: reference)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: managedURL(for: asset), options: .atomic)
        return asset
    }

    func removeImage(_ asset: ImageAsset) async throws {
        let url = try managedURL(for: asset)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func thumbnailData(for asset: ImageAsset, maximumPixelSize: Int) async throws -> Data {
        let url = try managedURL(for: asset)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw AssetError.unreadableImage
        }
        return try thumbnail(source: source, maximumPixelSize: maximumPixelSize)
    }

    private func managedURL(for asset: ImageAsset) throws -> URL {
        let reference = asset.localReference
        guard !reference.isEmpty, reference != ".", reference != "..",
              !reference.contains("/"), !reference.contains("\\") else {
            throw AssetError.invalidReference
        }
        return directory.appendingPathComponent(reference)
    }

    private func thumbnail(source: CGImageSource, maximumPixelSize: Int) throws -> Data {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, min(maximumPixelSize, 2048))
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw AssetError.unreadableImage
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw AssetError.unreadableImage
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw AssetError.unreadableImage }
        return data as Data
    }
}
