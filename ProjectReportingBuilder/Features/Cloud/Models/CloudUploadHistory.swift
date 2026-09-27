import Foundation

protocol CloudUploadTracking {
    func revision(for id: UUID) throws -> Int64
    func record(id: UUID, revision: Int64) throws
}

/// Keep acknowledged revisions separate from report files and recovery drafts.
final class CloudUploadHistory: CloudUploadTracking {
    private let file: URL
    init(file: URL) { self.file = file }

    func revision(for id: UUID) throws -> Int64 { try load()[id.uuidString] ?? 0 }

    func record(id: UUID, revision: Int64) throws {
        var values = try load()
        values[id.uuidString] = revision
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(values).write(to: file, options: .atomic)
    }

    private func load() throws -> [String: Int64] {
        guard FileManager.default.fileExists(atPath: file.path) else { return [:] }
        return try JSONDecoder().decode([String: Int64].self, from: Data(contentsOf: file))
    }
}
