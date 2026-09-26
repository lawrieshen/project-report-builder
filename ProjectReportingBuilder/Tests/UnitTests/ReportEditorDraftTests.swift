import Foundation
import Testing
@testable import Project_Report_Builder

struct ReportEditorDraftTests {
    @Test func legacyBusinessRequiresReselectionWithoutChangingOriginal() {
        let original = ProjectReport(id: UUID(), codeName: "Legacy", lineOfBusiness: "Camera",
                                     status: .draft, createdAt: .now, updatedAt: .now)
        var draft = ReportEditorDraft(project: original)
        #expect(draft.lineOfBusiness == "Camera")
        #expect(draft.lineOfBusinessError != nil)
        #expect(!draft.isValid)
        draft.lineOfBusiness = LineOfBusiness.iPhone.rawValue
        #expect(draft.isValid)
        #expect(original.lineOfBusiness == "Camera")
    }

    private func report() -> ProjectReport {
        ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "iPhone",
                      status: .active, createdAt: .distantPast, updatedAt: .distantPast)
    }

    @Test func defaultsDoNotModifyTheSource() {
        let project = report()
        let draft = ReportEditorDraft(project: project)
        #expect(draft.isValid)
        #expect(draft.ragStatus == nil)
        #expect(draft.summaryType == .update)
        #expect(draft.summaryMessage.isEmpty)
        #expect(project.card == nil)
    }

    @Test func validationRequiresIdentityAndPairedMilestone() {
        var draft = ReportEditorDraft(project: report())
        draft.codeName = " \n"
        #expect(draft.codeNameError != nil)
        draft.codeName = "Titan"
        draft.lineOfBusiness = " "
        #expect(draft.lineOfBusinessError != nil)
        draft.lineOfBusiness = "iPhone"
        draft.milestonePhase = "DVT"
        #expect(!draft.isValid)
        draft.milestoneDeadline = .now
        #expect(draft.isValid)
        draft.milestonePhase = ""
        #expect(!draft.isValid)
        draft.milestoneDeadline = nil
        #expect(draft.isValid)
    }

    @Test func mappingPreservesMetadataAndExistingIdentities() throws {
        var project = report()
        let lead = Person(id: UUID(), name: "Jane", role: "Lead")
        let cardID = UUID()
        project.card = SnippetCard(id: cardID,
            health: ProjectHealth(ragStatus: .green, milestone: nil),
            summary: ExecutiveSummary(type: .update, message: "Before"),
            accountability: Accountability(leadEPM: lead, projectDRI: nil))
        var draft = ReportEditorDraft(project: project)
        #expect(draft.leadEPMName == "Jane")
        draft.codeName = " Updated "
        draft.lineOfBusiness = " Services "
        draft.ragStatus = .red
        draft.milestonePhase = "DVT"
        let date = Date(timeIntervalSince1970: 100)
        draft.milestoneDeadline = date
        draft.summaryType = .ask
        draft.summaryMessage = "Need help"
        draft.leadEPMName = "Jane Smith"
        draft.projectDRIName = "Alex"
        let result = try draft.applying(to: project, cardID: UUID(), updatedAt: date)
        #expect(result.id == project.id)
        #expect(result.status == .active)
        #expect(result.createdAt == project.createdAt)
        #expect(result.updatedAt == date)
        #expect(result.codeName == "Updated")
        #expect(result.lineOfBusiness == "Services")
        let card = try #require(result.card)
        #expect(card.id == cardID)
        #expect(card.health.ragStatus == .red)
        #expect(card.health.milestone == Milestone(phase: "DVT", deadline: date))
        #expect(card.summary == ExecutiveSummary(type: .ask, message: "Need help"))
        #expect(card.accountability.leadEPM?.id == lead.id)
        #expect(card.accountability.leadEPM?.role == lead.role)
        #expect(card.accountability.leadEPM?.name == "Jane Smith")
        #expect(card.accountability.projectDRI?.name == "Alex")
        draft.leadEPMName = " "
        #expect(try draft.applying(to: result, cardID: cardID, updatedAt: date).card?.accountability.leadEPM == nil)
    }
}
