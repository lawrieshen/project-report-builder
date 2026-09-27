import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct CloudAccountStoreTests {
    @Test func nativeSignInSavesOnlyRefreshToken() async {
        let credentials = MemoryCloudCredentials()
        credentials.token = nil
        let native = StubPasswordClient()
        let store = CloudAccountStore(credentials: credentials, client: StubCognitoClient(), passwordClient: native)
        await store.signIn(email: " user@example.com ", password: "password")
        #expect(store.isSignedIn)
        #expect(credentials.token == "native-refresh")
        #expect(native.email == "user@example.com")
    }

    @Test func passwordChallengeCompletesBeforeSigningIn() async {
        let credentials = MemoryCloudCredentials()
        credentials.token = nil
        let native = StubPasswordClient()
        native.needsPassword = true
        let store = CloudAccountStore(credentials: credentials, client: StubCognitoClient(), passwordClient: native)
        await store.signIn(email: "user@example.com", password: "temporary")
        #expect(!store.isSignedIn)
        #expect(store.passwordChallenge != nil)
        #expect(credentials.token == nil)
        await store.setNewPassword("New-password-123")
        #expect(store.isSignedIn)
        #expect(store.passwordChallenge == nil)
        #expect(credentials.token == "native-refresh")
    }

    @Test func failedNativeSignInDoesNotSaveCredentials() async {
        let credentials = MemoryCloudCredentials()
        credentials.token = nil
        let native = StubPasswordClient()
        native.fails = true
        let store = CloudAccountStore(credentials: credentials, client: StubCognitoClient(), passwordClient: native)
        await store.signIn(email: "user@example.com", password: "wrong")
        #expect(!store.isSignedIn)
        #expect(!store.isBusy)
        #expect(store.message != nil)
        #expect(credentials.token == nil)
    }

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

    @Test func failedDraftBackupKeepsAccountSignedIn() async {
        let credentials = MemoryCloudCredentials()
        let store = CloudAccountStore(credentials: credentials, client: StubCognitoClient())
        await store.restore()
        let session = store.sessionID
        store.beforeSignOut = { throw StorageError.writeFailed("draft") }
        await store.signOut()
        #expect(store.isSignedIn)
        #expect(store.sessionID == session)
        #expect(credentials.token == "refresh")
        store.beforeSignOut = nil
        await store.signOut()
        #expect(store.sessionID != session)
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

@MainActor
private final class StubPasswordClient: CognitoPasswordServing {
    var needsPassword = false
    var fails = false
    var email: String?
    func signIn(email: String, password: String) async throws -> CognitoPasswordResult {
        self.email = email
        if fails { throw CognitoPasswordError.incorrectCredentials }
        if needsPassword { return .newPassword(CognitoPasswordChallenge(session: "challenge", username: email)) }
        return tokens()
    }
    func complete(_ challenge: CognitoPasswordChallenge, password: String) async throws -> CognitoPasswordResult {
        tokens()
    }
    private func tokens() -> CognitoPasswordResult {
        .authenticated(CognitoTokens(access_token: "native-access", refresh_token: "native-refresh",
                                     expires_in: 3600, token_type: "Bearer"))
    }
}
