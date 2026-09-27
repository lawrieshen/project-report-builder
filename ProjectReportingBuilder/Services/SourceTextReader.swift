import Foundation

/// Read a bounded UTF-8 text file while its sandbox access is available.
actor SourceTextReader: SourceTextReading {
    /// Decode a regular UTF-8 file of at most 1 MiB.
    ///
    /// Hold security-scoped access for the duration of the read and check the size
    /// both before and after loading the bytes.
    /// - Parameter url: A local file URL, typically supplied by the file importer.
    /// - Returns: The decoded text, preserving whitespace.
    /// - Throws: `TextImportError.invalidFile` for invalid input, or a file-system error.
    func read(from url: URL) throws -> String {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard url.isFileURL, values.isRegularFile == true,
              let size = values.fileSize, size <= 1_048_576 else {
            throw TextImportError.invalidFile
        }
        let data = try Data(contentsOf: url)
        guard data.count <= 1_048_576, let text = String(data: data, encoding: .utf8) else {
            throw TextImportError.invalidFile
        }
        return text
    }
}

enum TextImportError: LocalizedError {
    case invalidFile
    var errorDescription: String? { "Choose a UTF-8 plain-text file no larger than 1 MB." }
}
