import Foundation
import Observation

/// Manage cloud credentials independently of local editing and recovery.
@MainActor @Observable
final class CloudAccountStore {
    private(set) var sessionID = UUID()
    var signOutFailed: (() -> Void)?
    var beforeSignOut: (() async throws -> Void)?
    private(set) var isSignedIn = false
    private(set) var isBusy = false
    private(set) var message: String?
    private(set) var passwordChallenge: CognitoPasswordChallenge?
    private let passwordClient: any CognitoPasswordServing
    private var accessToken: String?
    private var expiresAt = Date.distantPast
    private let credentials: any CloudCredentialStoring
    private let client: any CognitoTokenServing
    private var restored = false

    convenience init() {
        self.init(credentials: CloudCredentialStore(), client: CognitoTokenClient())
    }

    init(credentials: any CloudCredentialStoring, client: any CognitoTokenServing,
         passwordClient: any CognitoPasswordServing = CognitoPasswordClient()) {
        self.passwordClient = passwordClient
        self.credentials = credentials
        self.client = client
    }

    func restore() async {
        guard !restored, !isBusy else { return }
        restored = true
        isBusy = true
        defer { isBusy = false }
        do {
            guard let refresh = try credentials.read() else { return }
            try await refreshSession(refresh)
        } catch { message = error.localizedDescription }
    }

    func signIn(email: String, password: String) async {
        guard !isBusy, !isSignedIn else { return }
        isBusy = true
        message = nil
        passwordChallenge = nil
        defer { isBusy = false }
        do {
            let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !email.isEmpty, !password.isEmpty else {
                throw CognitoPasswordError.incorrectCredentials
            }
            let result = try await passwordClient.signIn(email: email, password: password)
            try Task.checkCancellation()
            try finishSignIn(result)
        } catch { message = error.localizedDescription }
    }

    func setNewPassword(_ password: String) async {
        guard !isBusy, let challenge = passwordChallenge else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            let result = try await passwordClient.complete(challenge, password: password)
            try Task.checkCancellation()
            try finishSignIn(result)
        } catch { message = error.localizedDescription }
    }

    func cancelPasswordChallenge() {
        guard !isBusy else { return }
        passwordChallenge = nil
        message = nil
    }

    private func finishSignIn(_ result: CognitoPasswordResult) throws {
        switch result {
        case .newPassword(let challenge): passwordChallenge = challenge
        case .authenticated(let tokens):
            guard let refresh = tokens.refresh_token, !refresh.isEmpty else { throw CloudAuthError.invalidResponse }
            try credentials.save(refresh)
            passwordChallenge = nil
            accept(tokens)
        }
    }

    /// Refresh an expired access token before a future report API request.
    func validAccessToken() async throws -> String {
        if let accessToken, expiresAt > Date().addingTimeInterval(60) { return accessToken }
        guard let refresh = try credentials.read() else { throw CloudAuthError.expiredSession }
        try await refreshSession(refresh)
        guard let accessToken else { throw CloudAuthError.expiredSession }
        return accessToken
    }

    func signOut() async {
        guard !isBusy else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            try await beforeSignOut?()
            let refresh = try credentials.read()
            // If deletion fails, keep the session visible so the user can retry.
            try credentials.delete()
            accessToken = nil
            expiresAt = .distantPast
            isSignedIn = false
            sessionID = UUID()
            if let refresh {
                do { try await client.revoke(refresh) }
                catch { message = "Signed out on this Mac. Server token revocation could not be confirmed." }
            }
        } catch {
            signOutFailed?()
            message = error.localizedDescription
        }
    }

    private func refreshSession(_ refresh: String) async throws {
        let startedSession = sessionID
        do {
            let tokens = try await client.tokens(fields: ["grant_type": "refresh_token", "refresh_token": refresh])
            guard sessionID == startedSession else { throw CancellationError() }
            if let replacement = tokens.refresh_token { try credentials.save(replacement) }
            accept(tokens)
        } catch CloudAuthError.expiredSession {
            guard sessionID == startedSession else { throw CancellationError() }
            accessToken = nil
            isSignedIn = false
            sessionID = UUID()
            try credentials.delete()
            throw CloudAuthError.expiredSession
        }
    }

    private func accept(_ tokens: CognitoTokens) {
        if !isSignedIn { sessionID = UUID() }
        accessToken = tokens.access_token
        expiresAt = Date().addingTimeInterval(tokens.expires_in)
        isSignedIn = true
        message = nil
    }
}
