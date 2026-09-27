import Foundation

/// Read imported notes without coupling presentation state to file-system access.
protocol SourceTextReading: Sendable {
    /// Read source notes from an imported file.
    /// - Parameter url: The file selected for import.
    /// - Returns: Decoded notes, without applying them to a report.
    /// - Throws: An error if the file cannot be read or accepted by the reader.
    func read(from url: URL) async throws -> String
}
