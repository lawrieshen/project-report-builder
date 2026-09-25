import Foundation
import Testing
@testable import Project_Report_Builder

struct ImageAssetModelTests {
    @Test func assetsRoundTripThroughDraftAndCoding() throws {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                    status: .draft, createdAt: .now, updatedAt: .now)
        let asset = ImageAsset(id: UUID(), fileName: "diagram.png", localReference: "managed.png",
                               altText: "System diagram")
        var draft = ReportEditorDraft(project: project)
        draft.assets = [asset]
        let saved = try draft.applying(to: project, cardID: UUID(), updatedAt: .now)
        let decoded = try JSONDecoder().decode(ProjectReport.self, from: JSONEncoder().encode(saved))
        #expect(decoded.card?.assets == [asset])
        #expect(ReportEditorDraft(project: decoded).assets == [asset])
        #expect(decoded.template == project.template)
    }

    @Test func olderCardsDecodeWithNoAssets() throws {
        let card = SnippetCard(id: UUID(), health: ProjectHealth(ragStatus: nil, milestone: nil),
                               summary: ExecutiveSummary(type: .update, message: ""),
                               accountability: Accountability(leadEPM: nil, projectDRI: nil))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(card)) as? [String: Any])
        json.removeValue(forKey: "assets")
        let decoded = try JSONDecoder().decode(SnippetCard.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.assets.isEmpty)
    }
}
