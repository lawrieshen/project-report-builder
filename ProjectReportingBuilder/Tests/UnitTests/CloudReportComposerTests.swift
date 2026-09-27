import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct CloudReportComposerTests {
    private func request() throws -> CompositionRequest {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        let data = try Data(contentsOf: root.appendingPathComponent("backend/contracts/ai-compose/v1/request.json"))
        return try JSONDecoder().decode(CompositionRequest.self, from: data)
    }

    private func response(_ request: CompositionRequest) throws -> Data {
        try JSONEncoder().encode(CompositionResponse(requestID: request.requestID,
            baseDraftVersion: request.baseDraftVersion, candidateVersion: request.candidateVersion,
            goalID: request.goal.id, goalRevision: request.goal.revision,
            proposal: .init(assistantMessage: "Ready", clarifyingQuestions: [], proposedChanges: [],
                metricChanges: [], warnings: [], semanticFindings: []), remainingDailyRequests: 19))
    }

    private func http(_ request: URLRequest, _ status: Int) throws -> HTTPURLResponse {
        let url = try #require(request.url)
        return try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
    }

    @Test func pendingRetriesKeepTheSamePayloadAndCredentialDestination() async throws {
        let input = try request()
        let success = try response(input)
        var calls: [URLRequest] = []
        let service = CloudReportComposer(account: ComposerAccount(), transport: { request in
            calls.append(request)
            if calls.count == 1 { return (Data(#"{"code":"REQUEST_PENDING"}"#.utf8), try http(request, 409)) }
            return (success, try http(request, 200))
        }, wait: {})
        let result = try await service.compose(input)
        #expect(result.matches(input))
        #expect(calls.count == 2)
        #expect(calls[0].httpBody == calls[1].httpBody)
        #expect(calls[0].url?.absoluteString == "https://ic1fsr0eg6.execute-api.ap-southeast-2.amazonaws.com/ai/compose")
        #expect(calls[0].value(forHTTPHeaderField: "Authorization") == "Bearer dummy")
        #expect(calls[0].timeoutInterval == 35)
    }

    @Test func pendingRetriesAreBounded() async throws {
        var calls = 0
        let service = CloudReportComposer(account: ComposerAccount(), transport: { request in
            calls += 1
            return (Data(#"{"code":"REQUEST_PENDING"}"#.utf8), try http(request, 409))
        }, wait: {})
        do { _ = try await service.compose(request()); Issue.record("Expected pending") }
        catch let error as CompositionServiceError { #expect(error.code == .requestPending) }
        #expect(calls == 3)
    }

    @Test func changedSessionDuringTokenRefreshPreventsTransport() async throws {
        let account = ComposerAccount()
        account.changeDuringRefresh = true
        var calls = 0
        let service = CloudReportComposer(account: account, transport: { request in
            calls += 1
            return (Data(), try http(request, 200))
        })
        await #expect(throws: CancellationError.self) { try await service.compose(request()) }
        #expect(calls == 0)
    }

    @Test func changedSessionDuringNetworkRejectsResponse() async throws {
        let account = ComposerAccount()
        let input = try request()
        let success = try response(input)
        let service = CloudReportComposer(account: account, transport: { request in
            account.sessionID = UUID()
            return (success, try http(request, 200))
        })
        await #expect(throws: CancellationError.self) { try await service.compose(input) }
    }

    @Test func quotaFailureIsNotRetried() async throws {
        var calls = 0
        let service = CloudReportComposer(account: ComposerAccount(), transport: { request in
            calls += 1
            return (Data(#"{"code":"BUDGET_EXHAUSTED"}"#.utf8), try http(request, 429))
        }, wait: {})
        do { _ = try await service.compose(request()); Issue.record("Expected quota error") }
        catch let error as CompositionServiceError { #expect(error.code == .budgetExhausted) }
        #expect(calls == 1)
    }
}

@MainActor
private final class ComposerAccount: CompositionAuthorizing {
    var sessionID = UUID()
    var isSignedIn = true
    var changeDuringRefresh = false
    func validAccessToken() async throws -> String {
        if changeDuringRefresh { sessionID = UUID() }
        return "dummy"
    }
}
