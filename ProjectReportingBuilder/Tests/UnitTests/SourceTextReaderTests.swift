import Foundation
import Testing
@testable import Project_Report_Builder

struct SourceTextReaderTests {
    @Test func importsUTF8AndRejectsOversizedOrInvalidText() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        defer { try? FileManager.default.removeItem(at: url) }
        let reader = SourceTextReader()
        try Data("Summary: 中文 notes".utf8).write(to: url)
        #expect(try await reader.read(from: url) == "Summary: 中文 notes")
        try Data([0xff, 0xfe, 0xff]).write(to: url)
        await #expect(throws: (any Error).self) { try await reader.read(from: url) }
        try Data(repeating: 65, count: 1_048_577).write(to: url)
        await #expect(throws: (any Error).self) { try await reader.read(from: url) }
    }
}
