import AppKit
import AuthenticationServices
import Observation

@MainActor
private final class CloudSignInBrowser: NSObject, ASWebAuthenticationPresentationContextProviding {
    private var session: ASWebAuthenticationSession?
    private let window: NSWindow

    init(window: NSWindow) { self.window = window }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor { window }

    func authenticate(url: URL) async throws -> URL {
        defer { session = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: "projectreportbuilder") { url, error in
                if let error { continuation.resume(throwing: error) }
                else if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: CloudAuthError.invalidCallback) }
            }
            // An isolated browser session prevents the next login from silently reusing this account.
            session.prefersEphemeralWebBrowserSession = true
            session.presentationContextProvider = self
            self.session = session
            if !session.start() { continuation.resume(throwing: CloudAuthError.invalidResponse) }
        }
    }
}

/// Manage cloud credentials independently of local editing and recovery.
@MainActor @Observable
final class CloudAccountStore {
    private(set) var isSignedIn = false
    private(set) var isBusy = false
    private(set) var message: String?
    private var accessToken: String?
    private var expiresAt = Date.distantPast
    private let credentials: any CloudCredentialStoring
    private let client: any CognitoTokenServing
    private var restored = false

    convenience init() {
        self.init(credentials: CloudCredentialStore(), client: CognitoTokenClient())
    }

    init(credentials: any CloudCredentialStoring, client: any CognitoTokenServing) {
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

    func signIn() async {
        guard !isBusy else { return }
        isBusy = true
        message = nil
        defer { isBusy = false }
        do {
            guard let window = NSApp.keyWindow else { throw CloudAuthError.invalidResponse }
            let oauth = CognitoOAuth()
            let state = try CognitoOAuth.randomValue()
            let verifier = try CognitoOAuth.randomValue()
            let url = try oauth.authorizationURL(state: state, verifier: verifier)
            let callback = try await CloudSignInBrowser(window: window).authenticate(url: url)
            let code = try oauth.code(from: callback, state: state)
            let tokens = try await client.tokens(fields: ["grant_type": "authorization_code",
                "code": code, "redirect_uri": oauth.configuration.callback, "code_verifier": verifier])
            guard let refresh = tokens.refresh_token, !refresh.isEmpty else { throw CloudAuthError.invalidResponse }
            try credentials.save(refresh)
            accept(tokens)
        } catch ASWebAuthenticationSessionError.canceledLogin {
            message = "Sign-in cancelled. Your local reports are still available."
        } catch { message = error.localizedDescription }
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
            let refresh = try credentials.read()
            // If deletion fails, keep the session visible so the user can retry.
            try credentials.delete()
            accessToken = nil
            expiresAt = .distantPast
            isSignedIn = false
            if let refresh {
                do { try await client.revoke(refresh) }
                catch { message = "Signed out on this Mac. Server token revocation could not be confirmed." }
            }
        } catch { message = error.localizedDescription }
    }

    private func refreshSession(_ refresh: String) async throws {
        do {
            let tokens = try await client.tokens(fields: ["grant_type": "refresh_token", "refresh_token": refresh])
            if let replacement = tokens.refresh_token { try credentials.save(replacement) }
            accept(tokens)
        } catch CloudAuthError.expiredSession {
            accessToken = nil
            isSignedIn = false
            try credentials.delete()
            throw CloudAuthError.expiredSession
        }
    }

    private func accept(_ tokens: CognitoTokens) {
        accessToken = tokens.access_token
        expiresAt = Date().addingTimeInterval(tokens.expires_in)
        isSignedIn = true
        message = nil
    }
}
