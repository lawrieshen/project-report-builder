import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct ExportModelTests {
    @Test func namesCannotEscapeDestinationOrBecomeHiddenFiles() {
        #expect(ExportFileName.fileName("Project Titan", format: .png) == "Project-Titan.png")
        #expect(ExportFileName.fileName("../../foo:bar\\file", format: .html) == "foo-bar-file.html")
        #expect(ExportFileName.fileName(" \n./", format: .png) == "Report.png")
        #expect(!ExportFileName.baseName(".hidden").hasPrefix("."))
    }

    @Test func internationalNamesArePreservedAndBounded() {
        #expect(ExportFileName.baseName("專案 Titan") == "專案-Titan")
        #expect(ExportFileName.baseName(String(repeating: "專案", count: 100)).utf8.count <= 160)
        #expect(ExportFileName.baseName("Cafe\u{301}") == "Café")
    }

    @Test func exportOptionsDoNotDependOnPreviewZoom() {
        let options = ExportOptions(date: .distantPast)
        #expect(options.format == .png && options.background == .white)
        #expect(options.imageScale.factor == 1)
        #expect(ExportImageScale.highResolution.factor == 2)
        #expect(ExportFormat.html.mimeType == "text/html")
    }
}
