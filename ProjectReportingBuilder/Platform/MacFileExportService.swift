import AppKit
import UniformTypeIdentifiers

@MainActor
struct MacFileExportService: FileExporting {
    var chooseDestination: (ExportResult) async throws -> URL? = Self.showSavePanel

    func save(result: ExportResult) async throws -> URL? {
        guard let url = try await chooseDestination(result) else { return nil }
        try Task.checkCancellation()
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
        try result.data.write(to: url, options: .atomic)
        return url
    }

    private static func showSavePanel(_ result: ExportResult) async throws -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [result.contentType == .png ? .png : .html]
        panel.nameFieldStringValue = result.fileName
        panel.canCreateDirectories = true
        let response: NSApplication.ModalResponse = await withCheckedContinuation { continuation in
            if let window = NSApp.keyWindow {
                panel.beginSheetModal(for: window) { continuation.resume(returning: $0) }
            } else {
                panel.begin { continuation.resume(returning: $0) }
            }
        }
        return response == .OK ? panel.url : nil
    }
}
