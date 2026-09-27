import Foundation

@MainActor
protocol CompositionAuthorizing {
    var sessionID: UUID { get }
    var isSignedIn: Bool { get }
    func validAccessToken() async throws -> String
}

extension CloudAccountStore: CompositionAuthorizing { }

/// Send text-only composition requests to the fixed API, preserving IDs across bounded retries.
@MainActor
final class CloudReportComposer: ReportComposing {
    typealias Transport = (URLRequest) async throws -> (Data, URLResponse)
    private let account: any CompositionAuthorizing
    private let transport: Transport
    private let wait: () async throws -> Void

    init(account: any CompositionAuthorizing,
         transport: @escaping Transport = { try await URLSession.shared.data(for: $0, delegate: CompositionRedirectGuard()) },
         wait: @escaping () async throws -> Void = { try await Task.sleep(for: .seconds(1)) }) {
        self.account = account
        self.transport = transport
        self.wait = wait
    }

    func compose(_ input: CompositionRequest) async throws -> CompositionResponse {
        let sessionID = account.sessionID
        guard account.isSignedIn else { throw CloudTransferError.signedOut }
        let data = try JSONEncoder().encode(input)
        guard data.count <= 64_000 else { throw CompositionServiceError(code: .invalidInput) }
        let token = try await account.validAccessToken()
        try validateSession(sessionID)
        guard let url = URL(string: "https://ic1fsr0eg6.execute-api.ap-southeast-2.amazonaws.com/ai/compose") else {
            throw CompositionServiceError(code: .unavailable)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.timeoutInterval = 35
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for attempt in 0..<3 {
            try Task.checkCancellation()
            try validateSession(sessionID)
            let reply: (Data, URLResponse)
            do { reply = try await transport(request) }
            catch let error as URLError where attempt == 0 && [.timedOut, .networkConnectionLost].contains(error.code) {
                try await wait()
                continue
            }
            try validateSession(sessionID)
            try Task.checkCancellation()
            guard let http = reply.1 as? HTTPURLResponse, reply.0.count <= 160_000 else {
                throw CompositionServiceError(code: .invalidOutput)
            }
            if http.statusCode == 401 { throw CloudTransferError.signedOut }
            if http.statusCode == 200 {
                let result: CompositionResponse
                do { result = try JSONDecoder().decode(CompositionResponse.self, from: reply.0) }
                catch { throw CompositionServiceError(code: .invalidOutput) }
                guard result.matches(input), (0...20).contains(result.remainingDailyRequests) else {
                    throw CompositionServiceError(code: .invalidOutput)
                }
                return result
            }
            struct Failure: Decodable { let code: CompositionErrorCode }
            let code = (try? JSONDecoder().decode(Failure.self, from: reply.0).code) ?? .unavailable
            if code == .requestPending && http.statusCode == 409 && attempt < 2 {
                try await wait()
                continue
            }
            throw CompositionServiceError(code: code)
        }
        throw CompositionServiceError(code: .requestPending)
    }

    private func validateSession(_ expected: UUID) throws {
        guard account.isSignedIn, account.sessionID == expected else { throw CancellationError() }
    }
}

/// Do not forward report text or credentials through HTTP redirects.
nonisolated private final class CompositionRedirectGuard: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? { nil }
}
