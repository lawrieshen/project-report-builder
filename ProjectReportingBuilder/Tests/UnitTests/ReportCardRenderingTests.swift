import XCTest
import SwiftUI
@testable import Project_Report_Builder

@MainActor
final class ReportCardRenderingTests: XCTestCase {
    func testCanonicalCardRendersBothAppearancesAndCompactWidth() throws {
        let report = ProjectReport(id: UUID(), codeName: "Project Titan", lineOfBusiness: "iOS / Camera",
                                   status: .active, createdAt: .now, updatedAt: .now)
        var draft = ReportEditorDraft(project: report)
        draft.ragStatus = .amber
        draft.milestonePhase = "DVT Phase"
        draft.milestoneDeadline = Date(timeIntervalSince1970: 1_790_726_400)
        draft.summaryMessage = "Camera pipeline validation is progressing. Latency remains above target; the team is reviewing the final optimization."
        draft.summaryType = .update
        draft.leadEPMName = "Jane Smith"
        draft.projectDRIName = "Alex Chen"
        var latency = EngineeringMetricDraft()
        latency.name = "UI Latency"
        latency.currentValueText = "120"
        latency.unit = "ms"
        latency.hasTarget = true
        latency.targetValueText = "100"
        draft.metrics = [latency]
        let model = ReportPreviewModel(draft: draft)
        for scheme in [ColorScheme.light, .dark] {
            for width: CGFloat in [720, 320] {
                let card = ReportCardView(model: model, now: Date(timeIntervalSince1970: 1_790_294_400))
                    .frame(width: width)
                    .fixedSize(horizontal: false, vertical: true)
                    .environment(\.colorScheme, scheme)
                let renderer = ImageRenderer(content: card)
                let image = try XCTUnwrap(renderer.nsImage)
                XCTAssertEqual(image.size.width, width, accuracy: 1)
                XCTAssertGreaterThan(image.size.height, 300)
                let attachment = XCTAttachment(image: image)
                attachment.name = "Canonical report — \(scheme) — \(Int(width))pt"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}
