import Foundation

nonisolated struct StorageInformation: Sendable {
    let location: URL
    var projectCount = 0
    var assetCount = 0
    var bytes: Int64 = 0
    var warnings: [String] = []
}

extension ProjectFileStore {
    func information() throws -> StorageInformation {
        let loaded = try fetchProjects()
        var info = StorageInformation(location: storage.root, projectCount: loaded.projects.count, warnings: loaded.warnings)
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .isSymbolicLinkKey]
        guard let enumerator = FileManager.default.enumerator(at: storage.root,
            includingPropertiesForKeys: keys, options: []) else { throw StorageError.readFailed("storage information") }
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))
            guard values.isSymbolicLink != true, values.isRegularFile == true else { continue }
            info.bytes += Int64(values.fileSize ?? 0)
            if url.deletingLastPathComponent().lastPathComponent == "Assets" { info.assetCount += 1 }
        }
        return info
    }
}
