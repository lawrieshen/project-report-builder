import AppKit
import ImageIO
import UniformTypeIdentifiers

@MainActor
struct MacClipboardService: ClipboardWriting {
    var pasteboard: NSPasteboard = .general

    func writePNG(_ data: Data) throws {
        // Validate first so an invalid render cannot erase the user's clipboard.
        guard let image = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(image) as String? == UTType.png.identifier,
              CGImageSourceCreateImageAtIndex(image, 0, nil) != nil else {
            throw ExportError.clipboardFailed
        }
        pasteboard.clearContents()
        guard pasteboard.setData(data, forType: .png) else { throw ExportError.clipboardFailed }
    }
}
