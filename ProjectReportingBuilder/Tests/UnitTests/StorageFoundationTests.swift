import Foundation
import Testing
@testable import Project_Report_Builder

struct StorageFoundationTests {
    @Test func versionAndDirectoryBoundaries() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = ApplicationStorage(root: root)
        try storage.prepare()
        let id = UUID()
        #expect(storage.projectFile(id).lastPathComponent == "project.json")
        #expect(storage.assets(id).deletingLastPathComponent() == storage.projectDirectory(id))
        #expect(try StoredDocument<String>.decode(JSONEncoder().encode(StoredDocument("draft"))) == "draft")
        let future = Data(#"{"schemaVersion":99,"value":"draft"}"#.utf8)
        #expect(throws: StorageError.self) { try StoredDocument<String>.decode(future) }
        #expect(throws: (any Error).self) { try StoredDocument<String>.decode(Data("broken".utf8)) }
    }
}
