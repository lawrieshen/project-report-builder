import Foundation

@MainActor
protocol ReportExportRendering {
    func render(model: ReportPreviewModel, options: ExportOptions) async throws -> ExportResult
}

@MainActor
protocol ClipboardWriting {
    func writePNG(_ data: Data) throws
}

@MainActor
protocol FileExporting {
    /// Return nil when the user cancels without writing a file.
    func save(result: ExportResult) async throws -> URL?
}

@MainActor
protocol ReportSharing {
    /// Present the native share picker; returning does not mean delivery succeeded.
    func share(result: ExportResult) throws
}
