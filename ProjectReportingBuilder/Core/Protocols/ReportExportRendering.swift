import Foundation

/// Render a report snapshot into a portable export without presenting system UI.
@MainActor
protocol ReportExportRendering {
    func render(model: ReportPreviewModel, options: ExportOptions) async throws -> ExportResult
}

/// Publish rendered PNG data to the platform clipboard.
@MainActor
protocol ClipboardWriting {
    func writePNG(_ data: Data) throws
}

/// Let the user choose where to save a rendered report.
@MainActor
protocol FileExporting {
    /// Return nil when the user cancels without writing a file.
    func save(result: ExportResult) async throws -> URL?
}

/// Hand a rendered report to the platform sharing interface.
@MainActor
protocol ReportSharing {
    /// Present the native share picker; returning does not mean delivery succeeded.
    func share(result: ExportResult) throws
}
