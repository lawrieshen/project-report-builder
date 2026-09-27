import SwiftUI
import ImageIO

/// Render the same immutable presentation model and card used by Live Preview.
@MainActor
struct ReportExportRenderer: ReportExportRendering {
    let loadImage: (ImageAsset) async throws -> Data

    /// Prepare images and encode the report in the requested format.
    ///
    /// - Parameters:
    ///   - model: The immutable report presentation snapshot.
    ///   - options: Format, appearance, resolution, and rendering date.
    /// - Returns: Encoded content with its suggested filename and format.
    /// - Throws: `CancellationError` or an export error for unavailable images,
    ///   unsafe output size, or failed rendering.
    /// - Note: Rendering runs on the main actor and does not persist the report.
    func render(model: ReportPreviewModel, options: ExportOptions) async throws -> ExportResult {
        try Task.checkCancellation()
        let images = try await preparedImages(model.assets)
        try Task.checkCancellation()
        let data: Data
        switch options.format {
        case .png: data = try png(model: model, images: images, options: options)
        case .html: data = try ReportHTMLRenderer.render(model: model, images: images, options: options)
        }
        return ExportResult(data: data, fileName: ExportFileName.fileName(model.codeName, format: options.format),
                            contentType: options.format)
    }

    /// Decode all images before rendering so loading indicators can never enter an export.
    func preparedImages(_ assets: [ImageAsset]) async throws -> [String: NSImage] {
        var images: [String: NSImage] = [:]
        var decodedPixels = 0
        for asset in assets {
            try Task.checkCancellation()
            if images[asset.localReference] != nil { continue }
            let data: Data
            do {
                data = try await loadImage(asset)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw ExportError.imageUnavailable(asset.fileName)
            }
            try Task.checkCancellation()
            let decoding: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1440, kCGImageSourceCreateThumbnailWithTransform: true]
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let image = CGImageSourceCreateThumbnailAtIndex(source, 0, decoding as CFDictionary) else {
                throw ExportError.imageUnavailable(asset.fileName)
            }
            decodedPixels += image.width * image.height
            guard decodedPixels <= 40_000_000 else { throw ExportError.reportTooLarge }
            images[asset.localReference] = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        }
        return images
    }

    private func png(model: ReportPreviewModel, images: [String: NSImage], options: ExportOptions) throws -> Data {
        let scheme: ColorScheme = options.background == .system && options.appearance == .dark ? .dark : .light
        let card = ReportCardView(model: model, images: images.mapValues { .loaded($0) },
                                  now: options.date, drawsBackground: options.background != .transparent)
            .frame(width: ReportCardStyle.standardWidth)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.colorScheme, scheme)
            .background(options.background == .transparent ? Color.clear : ReportAccessibilityStyle.canonical.palette(scheme).background.color)
        let renderer = ImageRenderer(content: card)
        let scale = options.imageScale.factor
        renderer.scale = scale
        var measuredSize: CGSize?
        renderer.render(rasterizationScale: scale) { size, _ in measuredSize = size }
        guard let measuredSize else { throw ExportError.renderingFailed }
        guard Self.isSafeRasterSize(measuredSize, scale: scale) else { throw ExportError.reportTooLarge }
        guard let image = renderer.cgImage,
              let output = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw ExportError.renderingFailed
        }
        return output
    }

    /// Bound allocation before creating the raster context, including scale and overflow.
    static func isSafeRasterSize(_ size: CGSize, scale: Double) -> Bool {
        let width = ceil(size.width * scale), height = ceil(size.height * scale)
        return width.isFinite && height.isFinite && width > 0 && height > 0
            && width <= 32_768 && height <= 32_768 && width * height <= 40_000_000
    }
}
