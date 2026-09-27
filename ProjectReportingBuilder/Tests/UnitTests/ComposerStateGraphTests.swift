import Foundation
import Testing
@testable import Project_Report_Builder

struct ComposerStateGraphTests {
    private func version() -> CompositionVersion {
        CompositionVersion(accountSessionID: UUID(), reportID: UUID(), baseDraftVersion: UUID(),
            goal: ReportCompositionGoal(), candidateVersion: UUID())
    }

    @Test func oneSendAndNoLateResponseAfterCancellation() {
        let version = version()
        var graph = ComposerStateGraph(version: version)
        let id = UUID()
        let accepted1 = graph.send(.send(requestID: id, version: version))
        #expect(accepted1)
        let accepted2 = !graph.send(.send(requestID: UUID(), version: version))
        #expect(accepted2)
        let accepted3 = graph.send(.cancel)
        #expect(accepted3)
        let accepted4 = !graph.send(.received(requestID: id, version: version, candidateVersion: UUID()))
        #expect(accepted4)
        #expect(graph.version == version)
        #expect(graph.state == .ready)
    }

    @Test func draftChangesAndClosingInvalidatePendingWork() {
        for invalidation in [ComposerEvent.baseChanged, .close] {
            let version = version()
            var graph = ComposerStateGraph(version: version)
            let id = UUID()
            graph.send(.send(requestID: id, version: version))
            let accepted5 = graph.send(invalidation)
            #expect(accepted5)
            let accepted6 = !graph.send(.received(requestID: id, version: version, candidateVersion: UUID()))
            #expect(accepted6)
            let accepted7 = !graph.send(.apply(version: version, editorAllowsApply: true, acceptUnfinishedGoal: true))
            #expect(accepted7)
        }
    }

    @Test func failuresPreserveVersionAndRequireExplicitRetry() {
        let version = version()
        for limited in [false, true] {
            var graph = ComposerStateGraph(version: version)
            let id = UUID()
            graph.send(.send(requestID: id, version: version))
            let accepted8 = !graph.send(.failure(requestID: UUID(), limited: limited))
            #expect(accepted8)
            let accepted9 = graph.send(.failure(requestID: id, limited: limited))
            #expect(accepted9)
            #expect(graph.version == version)
            #expect(graph.state == (limited ? .limited : .failed))
            let accepted10 = graph.send(.send(requestID: UUID(), version: version))
            #expect(accepted10)
        }
    }

    @Test func applyRequiresReviewAndEditorPermission() {
        let version = version()
        var graph = ComposerStateGraph(version: version)
        let accepted11 = !graph.send(.apply(version: version, editorAllowsApply: true, acceptUnfinishedGoal: true))
        #expect(accepted11)
        let id = UUID()
        graph.send(.send(requestID: id, version: version))
        graph.send(.received(requestID: id, version: version, candidateVersion: UUID()))
        #expect(graph.state == .evaluating)
        graph.send(.evaluated(hasQuestions: false))
        let accepted12 = !graph.send(.apply(version: graph.version, editorAllowsApply: false, acceptUnfinishedGoal: true))
        #expect(accepted12)
        let accepted13 = !graph.send(.apply(version: graph.version, editorAllowsApply: true, acceptUnfinishedGoal: false))
        #expect(accepted13)
        let accepted14 = graph.send(.apply(version: graph.version, editorAllowsApply: true, acceptUnfinishedGoal: true))
        #expect(accepted14)
        #expect(graph.confirmation == nil)
    }

    @Test func newAccountCannotRebaseOldCandidate() {
        var graph = ComposerStateGraph(version: version())
        graph.send(.baseChanged)
        let accepted15 = !graph.send(.rebase(version()))
        #expect(accepted15)
        graph.send(.close)
        let accepted16 = !graph.send(.baseChanged)
        #expect(accepted16)
    }
}
