import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct CloudAccountStoreTests {
    @Test func restoreRefreshesAndCachesAccessToken() async throws {
        let credentials = MemoryCloudCredentials()
        let client = StubCognitoClient()
        let store = CloudAccountStore(credentials: credentials, client: client)
        await store.restore()
        #expect(store.isSignedIn)
        #expect(try await store.validAccessToken() == "access")
        #expect(client.refreshCount == 1)
        #expect(credentials.token == "refresh")
    }

    @Test func expiredRefreshTokenClearsSavedSession() async {
        let credentials = MemoryCloudCredentials()
        let client = StubCognitoClient()
        client.failure = .expiredSession
        let store = CloudAccountStore(credentials: credentials, client: client)
        await store.restore()
        #expect(!store.isSignedIn)
        #expect(credentials.token == nil)
        #expect(store.message != nil)
    }

    @Test func temporaryFailurePreservesRefreshToken() async {
        let credentials = MemoryCloudCredentials()
        let client = StubCognitoClient()
        client.failure = .invalidResponse
        let store = CloudAccountStore(credentials: credentials, client: client)
        await store.restore()
        #expect(credentials.token == "refresh")
        #expect(store.message != nil)
    }

    @Test func signOutDeletesLocalTokenEvenWhenRevocationFails() async {
        let credentials = MemoryCloudCredentials()
        let client = StubCognitoClient()
        let store = CloudAccountStore(credentials: credentials, client: client)
        await store.restore()
        client.failure = .invalidResponse
        await store.signOut()
        #expect(!store.isSignedIn)
        #expect(credentials.token == nil)
        #expect(client.revoked == "refresh")
        #expect(store.message?.contains("could not be confirmed") == true)
    }

    @Test func keychainDeletionFailureAllowsSignOutRetry() async {
        let credentials = MemoryCloudCredentials()
        let client = StubCognitoClient()
        let store = CloudAccountStore(credentials: credentials, client: client)
        await store.restore()
        credentials.failDelete = true
        await store.signOut()
        #expect(store.isSignedIn)
        #expect(client.revoked == nil)
        credentials.failDelete = false
        await store.signOut()
        #expect(!store.isSignedIn)
    }
}

@MainActor
private final class MemoryCloudCredentials: CloudCredentialStoring {
    var token: String? = "refresh"
    var failDelete = false
    func read() throws -> String? { token }
    func save(_ token: String) throws { self.token = token }
    func delete() throws {
        if failDelete { throw CloudAuthError.keychain(-1) }
        token = nil
    }
}

@MainActor
private final class StubCognitoClient: CognitoTokenServing {
    var failure: CloudAuthError?
    var refreshCount = 0
    var revoked: String?
    func tokens(fields: [String: String]) async throws -> CognitoTokens {
        refreshCount += 1
        if let failure { throw failure }
        return CognitoTokens(access_token: "access", refresh_token: nil, expires_in: 3600, token_type: "Bearer")
    }
    func revoke(_ refreshToken: String) async throws {
        revoked = refreshToken
        if let failure { throw failure }
    }
}
