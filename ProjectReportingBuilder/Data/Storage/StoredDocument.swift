import Foundation

/// Check the format version before decoding domain values.
struct StoredDocument<Value: Codable>: Codable {
    let schemaVersion: Int
    let value: Value

    init(_ value: Value) {
        schemaVersion = 1
        self.value = value
    }

    static func decode(_ data: Data) throws -> Value {
        let decoder = JSONDecoder()
        let version = try decoder.decode(StorageVersion.self, from: data)
        guard version.schemaVersion == 1 else { throw StorageError.unsupportedVersion(version.schemaVersion) }
        return try decoder.decode(Self.self, from: data).value
    }
}

private struct StorageVersion: Decodable { let schemaVersion: Int }

enum StorageError: LocalizedError {
    case unsupportedVersion(Int)
    case readFailed(String)
    case writeFailed(String)
    case deleteFailed
    case projectMissing
    case invalidReference

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version): return "Storage version \(version) is not supported. Update the app before opening this data."
        case .readFailed(let name): return "Unable to read \(name). The file may be damaged or inaccessible."
        case .writeFailed(let name): return "Unable to write \(name). Check available disk space and folder permissions."
        case .deleteFailed: return "Unable to delete this project. Its files may be in use or inaccessible."
        case .projectMissing: return "This project no longer exists."
        case .invalidReference: return "The stored image reference is invalid."
        }
    }
}
