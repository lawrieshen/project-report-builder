import Foundation

/// Read imported notes without coupling presentation state to file-system access.
protocol SourceTextReading: Sendable {
    func read(from url: URL) async throws -> String
}
