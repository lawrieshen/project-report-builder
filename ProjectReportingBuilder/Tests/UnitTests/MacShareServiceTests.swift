import AppKit
import Testing
@testable import Project_Report_Builder

@MainActor
struct MacShareServiceTests {
    @Test func sharesUseSeparateFilesAndCleanOnlyTheirOwnDirectory() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ShareFileStore(root: root)
        let result = ExportResult(data: Data("report".utf8), fileName: "../../Titan.html", contentType: .html)
        let first = try store.create(result), second = try store.create(result)
        #expect(first != second && first.lastPathComponent == "Titan.html")
        #expect(try Data(contentsOf: first) == result.data)
        store.remove(first)
        #expect(!FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
        let outside = root.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: outside)
        store.remove(outside)
        #expect(FileManager.default.fileExists(atPath: outside.path))
        store.removeExpired(before: .distantFuture)
        #expect(!FileManager.default.fileExists(atPath: second.path))
        #expect(FileManager.default.fileExists(atPath: outside.path))
    }

    @Test func noWindowReportsPresentationFailureWithoutCreatingAFile() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = MacShareService(files: ShareFileStore(root: root), anchorView: { nil })
        do {
            try service.share(result: ExportResult(data: Data(), fileName: "Titan.png", contentType: .png))
            Issue.record("Sharing without a window must fail")
        } catch {
            #expect(!FileManager.default.fileExists(atPath: root.path))
        }
    }
}
