import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct MetricWorkspaceTests {
    private func metric(_ name: String) -> EngineeringMetricDraft {
        var metric = EngineeringMetricDraft()
        metric.name = name
        metric.currentValueText = "120"
        return metric
    }

    @Test func changesSaveReopenAndDiscardWithStableIdentity() async throws {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                    status: .active, template: .technical, createdAt: .now, updatedAt: .now)
        let repository = WorkspaceTestRepository(project: project)
        let model = ReportEditorViewModel(projectID: project.id, repository: repository)
        await model.load()
        var first = metric("Latency")
        let second = metric("Bugs")
        #expect(model.addMetric(first) == nil)
        #expect(model.addMetric(second) == nil)
        #expect(model.isDirty)
        #expect(repository.saveCount == 0)
        first.currentValueText = "99"
        #expect(model.updateMetric(first) == nil)
        #expect(model.draft?.metrics.count == 2)
        model.moveMetric(fromOffsets: IndexSet(integer: 0), toOffset: 2)
        #expect(model.draft?.metrics.map(\.id) == [second.id, first.id])
        #expect(await model.save())
        #expect(!model.isDirty)
        #expect(repository.project?.template == .technical)
        #expect(repository.project?.card?.metrics.map(\.id) == [second.id, first.id])
        #expect(repository.project?.card?.metrics.last?.currentValue == 99)
        model.deleteMetric(id: first.id)
        #expect(model.isDirty)
        model.discardChanges()
        #expect(!model.isDirty)
        #expect(model.draft?.metrics.count == 2)
        model.moveMetric(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        #expect(model.draft?.metrics.map(\.id) == [first.id, second.id])
        model.discardChanges()
        let reopened = ReportEditorViewModel(projectID: project.id, repository: repository)
        await reopened.load()
        #expect(reopened.draft == model.draft)
    }

    @Test func invalidOperationsAndFailedSavePreserveMetrics() async {
        let project = ProjectReport(id: UUID(), codeName: "Titan", lineOfBusiness: "Camera",
                                    status: .draft, createdAt: .now, updatedAt: .now)
        let repository = WorkspaceTestRepository(project: project)
        let model = ReportEditorViewModel(projectID: project.id, repository: repository)
        await model.load()
        let first = metric("Latency")
        #expect(model.addMetric(first) == nil)
        let before = model.draft
        #expect(model.addMetric(first) != nil)
        #expect(model.addMetric(metric(" LATENCY ")) != nil)
        #expect(model.updateMetric(metric("Missing")) != nil)
        model.moveMetric(fromOffsets: IndexSet(integer: 10), toOffset: 0)
        model.moveMetric(fromOffsets: IndexSet(integer: 0), toOffset: -1)
        #expect(model.draft == before)
        repository.failSave = true
        #expect(await model.save() == false)
        #expect(model.draft == before)
        #expect(model.isDirty)
        #expect(repository.project?.card == nil)
        repository.failSave = false
        #expect(await model.save())
        model.deleteMetric(id: first.id)
        #expect(await model.save())
        #expect(repository.project?.card?.metrics.isEmpty == true)
    }
}
