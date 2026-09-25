import SwiftUI
import ImageIO

/// Render the same immutable presentation model and card used by Live Preview.
@MainActor
struct ReportExportRenderer: ReportExportRendering {
    let loadImage: (ImageAsset) async throws -> Data

    func render(model: ReportPreviewModel, options: ExportOptions) async throws -> ExportResult {
        try Task.checkCancellation()
        guard options.format == .png else { throw ExportError.unsupportedFormat }
        let images = try await preparedImages(model.assets)
        try Task.checkCancellation()
        let data = try png(model: model, images: images, options: options)
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
        let renderer = ImageRenderer(content: card)
        let scale = options.imageScale.factor
        var output: Data?
        var failure: ExportError = .renderingFailed
        renderer.render(rasterizationScale: scale) { size, draw in
            guard Self.isSafeRasterSize(size, scale: scale) else {
                failure = .reportTooLarge
                return
            }
            let width = Int(ceil(size.width * scale)), height = Int(ceil(size.height * scale))
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.scaleBy(x: scale, y: scale)
            if options.background != .transparent {
                let background = ReportAccessibilityStyle.canonical.palette(scheme).background
                context.setFillColor(CGColor(red: background.red, green: background.green, blue: background.blue, alpha: 1))
                context.fill(CGRect(origin: .zero, size: size))
            }
            draw(context)
            guard let image = context.makeImage() else { return }
            output = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        }
        guard let output else { throw failure }
        return output
    }

    /// Bound allocation before creating the raster context, including scale and overflow.
    static func isSafeRasterSize(_ size: CGSize, scale: Double) -> Bool {
        let width = ceil(size.width * scale), height = ceil(size.height * scale)
        return width.isFinite && height.isFinite && width > 0 && height > 0
            && width <= 32_768 && height <= 32_768 && width * height <= 40_000_000
    }
}
