import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct MacFileExportServiceTests {
    private let result = ExportResult(data: Data("<html>Current draft</html>".utf8), fileName: "Titan.html", contentType: .html)

    @Test func selectedFileReceivesExactRenderedBytes() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".html")
        defer { try? FileManager.default.removeItem(at: url) }
        let service = MacFileExportService { received in
            #expect(received.fileName == "Titan.html" && received.contentType == .html)
            return url
        }
        let saved = try await service.save(result: result)
        #expect(saved == url)
        #expect(try Data(contentsOf: url) == result.data)
    }

    @Test func cancellationReturnsNoDestination() async throws {
        let service = MacFileExportService { _ in nil }
        #expect(try await service.save(result: result) == nil)
    }

    @Test func writeFailureIsReported() async {
        let service = MacFileExportService { _ in
            FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("missing.html")
        }
        do {
            _ = try await service.save(result: result)
            Issue.record("Missing parent directory must fail")
        } catch {
            #expect((error as NSError).domain == NSCocoaErrorDomain)
        }
    }
}
