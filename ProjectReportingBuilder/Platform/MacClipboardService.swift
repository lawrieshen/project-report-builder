import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Validate rendered PNG bytes before replacing the macOS clipboard.
@MainActor
struct MacClipboardService: ClipboardWriting {
    var pasteboard: NSPasteboard = .general

    /// Replace the clipboard with a decodable PNG image.
    /// - Parameter data: Encoded PNG bytes from the renderer.
    /// - Throws: `ExportError.clipboardFailed` for invalid PNG data or a failed pasteboard write.
    /// - Note: Invalid input leaves the previous clipboard contents intact.
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
