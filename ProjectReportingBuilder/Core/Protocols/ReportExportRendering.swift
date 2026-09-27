import Foundation

@MainActor
protocol ReportExportRendering {
    /// Render an immutable report snapshot for export.
    ///
    /// - Parameters:
    ///   - model: The content snapshot, which may include unsaved changes.
    ///   - options: Output format and presentation settings.
    /// - Returns: Encoded output and suggested file metadata.
    /// - Throws: An error if rendering or asset preparation fails, or work is cancelled.
    func render(model: ReportPreviewModel, options: ExportOptions) async throws -> ExportResult
}

@MainActor
protocol ClipboardWriting {
    /// Write an encoded PNG image to the system clipboard.
    ///
    /// - Parameter data: PNG image bytes.
    /// - Throws: An error if the image cannot be accepted or written.
    func writePNG(_ data: Data) throws
}

@MainActor
protocol FileExporting {
    /// Present a destination picker and save exported content.
    ///
    /// - Parameter result: The encoded export and suggested filename.
    /// - Returns: The saved URL, or `nil` when the user cancels.
    /// - Throws: An error if the write fails.
    func save(result: ExportResult) async throws -> URL?
}

@MainActor
protocol ReportSharing {
    /// Present the native share picker for exported content.
    ///
    /// - Parameter result: The encoded export to share.
    /// - Throws: An error if sharing cannot be prepared or presented.
    /// - Note: Returning confirms presentation, not delivery to a recipient.
    func share(result: ExportResult) throws
}
