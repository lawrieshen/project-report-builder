import Foundation
import Testing
@testable import Project_Report_Builder

struct CompositionContractTests {
    private func fixture(_ name: String) throws -> Data {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        return try Data(contentsOf: root.appendingPathComponent("backend/contracts/ai-compose/v1/\(name).json"))
    }

    @Test func sharedFixturesRoundTripAndEchoExactInputVersion() throws {
        let decoder = JSONDecoder()
        let request = try decoder.decode(CompositionRequest.self, from: fixture("request"))
        let response = try decoder.decode(CompositionResponse.self, from: fixture("response"))
        #expect(response.matches(request))
        #expect(response.proposal.proposedChanges.first?.field == .summaryMessage)
        #expect(try decoder.decode(CompositionRequest.self, from: JSONEncoder().encode(request)) == request)
        let unrelated = CompositionRequest(requestID: UUID(), baseDraftVersion: request.baseDraftVersion,
            candidateVersion: request.candidateVersion, goal: request.goal, draft: request.draft, messages: request.messages)
        #expect(!response.matches(unrelated))
    }

    @Test func contextNeverIncludesImageReferencesOrStorageMetadata() throws {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Mac", status: .active,
                                    createdAt: .now, updatedAt: .now)
        var draft = ReportEditorDraft(project: project)
        draft.assets = [ImageAsset(id: UUID(), fileName: "private.png", localReference: "/private/private.png")]
        let data = try JSONEncoder().encode(CompositionDraft(draft: draft))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["assets"] == nil)
        #expect(object["status"] == nil)
        #expect(object["id"] == nil)
        #expect(!String(decoding: data, as: UTF8.self).contains("private.png"))
    }
}
