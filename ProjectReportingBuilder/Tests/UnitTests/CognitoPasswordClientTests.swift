import Foundation
import Testing
@testable import Project_Report_Builder

@Suite(.serialized)
@MainActor
struct CognitoPasswordClientTests {
    private func client(status: Int = 200, json: String) -> CognitoPasswordClient {
        PasswordURLProtocol.status = status
        PasswordURLProtocol.body = Data(json.utf8)
        PasswordURLProtocol.lastRequest = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [PasswordURLProtocol.self]
        return CognitoPasswordClient(session: URLSession(configuration: config))
    }

    @Test func passwordLoginUsesCognitoAndDecodesTokens() async throws {
        let client = client(json: #"{"AuthenticationResult":{"AccessToken":"access","RefreshToken":"refresh","ExpiresIn":3600,"TokenType":"Bearer"}}"#)
        guard case .authenticated(let tokens) = try await client.signIn(email: "user@example.com", password: "test-password") else {
            Issue.record("Expected tokens"); return
        }
        #expect(tokens.refresh_token == "refresh")
        #expect(PasswordURLProtocol.lastRequest?.url?.host == "cognito-idp.ap-southeast-2.amazonaws.com")
        #expect(PasswordURLProtocol.lastRequest?.value(forHTTPHeaderField: "X-Amz-Target") == "AWSCognitoIdentityProviderService.InitiateAuth")
    }

    @Test func temporaryPasswordUsesCanonicalChallengeUsername() async throws {
        let client = client(json: #"{"ChallengeName":"NEW_PASSWORD_REQUIRED","Session":"challenge","ChallengeParameters":{"USER_ID_FOR_SRP":"canonical","requiredAttributes":"[]"}}"#)
        guard case .newPassword(let challenge) = try await client.signIn(email: "user@example.com", password: "temporary") else {
            Issue.record("Expected password challenge"); return
        }
        #expect(challenge.username == "canonical")
        #expect(challenge.session == "challenge")
    }

    @Test func unknownChallengeDoesNotAuthenticate() async throws {
        let client = client(json: #"{"ChallengeName":"SOFTWARE_TOKEN_MFA","Session":"challenge"}"#)
        await #expect(throws: CognitoPasswordError.self) {
            try await client.signIn(email: "user@example.com", password: "password")
        }
    }

    @Test func wrongPasswordAndExpiredRefreshHaveDifferentErrors() async throws {
        let client = client(status: 400, json: #"{"__type":"NotAuthorizedException"}"#)
        await #expect(throws: CognitoPasswordError.self) {
            try await client.signIn(email: "user@example.com", password: "wrong")
        }
        await #expect(throws: CloudAuthError.self) { try await client.refresh("expired") }
    }

    @Test func refreshUsesNativeAuthFlow() async throws {
        let client = client(json: #"{"AuthenticationResult":{"AccessToken":"updated","ExpiresIn":3600,"TokenType":"Bearer"}}"#)
        #expect(try await client.refresh("refresh").access_token == "updated")
        #expect(PasswordURLProtocol.lastRequest?.value(forHTTPHeaderField: "X-Amz-Target") == "AWSCognitoIdentityProviderService.InitiateAuth")
    }
}

private final class PasswordURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var status = 200
    nonisolated(unsafe) static var body = Data()
    nonisolated(unsafe) static var lastRequest: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lastRequest = request
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: Self.status, httpVersion: nil, headerFields: nil) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
