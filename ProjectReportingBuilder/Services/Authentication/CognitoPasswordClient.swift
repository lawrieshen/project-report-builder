import Foundation

/// Keep Cognito challenge sessions in memory until sign-in completes.
struct CognitoPasswordChallenge {
    let session: String
    let username: String
}

enum CognitoPasswordResult {
    case authenticated(CognitoTokens)
    case newPassword(CognitoPasswordChallenge)
}

enum CognitoPasswordError: LocalizedError {
    case incorrectCredentials, throttled, passwordPolicy, unsupportedChallenge, accountAction

    var errorDescription: String? {
        switch self {
        case .incorrectCredentials: "Incorrect email or password. Please try again."
        case .throttled: "Too many attempts. Please wait before trying again."
        case .passwordPolicy: "Use at least 12 characters with uppercase, lowercase, numbers, and symbols."
        case .unsupportedChallenge: "This account requires an additional verification step. Please contact your administrator."
        case .accountAction: "Please contact your administrator to activate or reset this account."
        }
    }
}

protocol CognitoPasswordServing {
    func signIn(email: String, password: String) async throws -> CognitoPasswordResult
    func complete(_ challenge: CognitoPasswordChallenge, password: String) async throws -> CognitoPasswordResult
}

/// Send credentials directly to Cognito over HTTPS, without AWS keys or a client secret.
struct CognitoPasswordClient: CognitoPasswordServing {
    var session: URLSession = .shared
    private let configuration = CognitoConfiguration()

    func signIn(email: String, password: String) async throws -> CognitoPasswordResult {
        let response = try await send(operation: "InitiateAuth", body: [
            "ClientId": configuration.clientID, "AuthFlow": "USER_PASSWORD_AUTH",
            "AuthParameters": ["USERNAME": email, "PASSWORD": password]
        ])
        return try result(response, username: email)
    }

    func complete(_ challenge: CognitoPasswordChallenge, password: String) async throws -> CognitoPasswordResult {
        let response = try await send(operation: "RespondToAuthChallenge", body: [
            "ClientId": configuration.clientID, "ChallengeName": "NEW_PASSWORD_REQUIRED",
            "Session": challenge.session,
            "ChallengeResponses": ["USERNAME": challenge.username, "NEW_PASSWORD": password]
        ])
        return try result(response, username: challenge.username)
    }

    func refresh(_ token: String) async throws -> CognitoTokens {
        do {
            let response = try await send(operation: "InitiateAuth", body: [
                "ClientId": configuration.clientID, "AuthFlow": "REFRESH_TOKEN_AUTH",
                "AuthParameters": ["REFRESH_TOKEN": token]
            ])
            guard case .authenticated(let tokens) = try result(response, username: "") else {
                throw CloudAuthError.invalidResponse
            }
            return tokens
        } catch CognitoPasswordError.incorrectCredentials {
            throw CloudAuthError.expiredSession
        }
    }

    private func result(_ response: Response, username: String) throws -> CognitoPasswordResult {
        if let auth = response.AuthenticationResult {
            guard !auth.AccessToken.isEmpty, auth.ExpiresIn > 0,
                  auth.TokenType.lowercased() == "bearer" else { throw CloudAuthError.invalidResponse }
            return .authenticated(CognitoTokens(access_token: auth.AccessToken,
                refresh_token: auth.RefreshToken, expires_in: auth.ExpiresIn, token_type: auth.TokenType))
        }
        guard response.ChallengeName == "NEW_PASSWORD_REQUIRED" else {
            throw CognitoPasswordError.unsupportedChallenge
        }
        if let required = response.ChallengeParameters?["requiredAttributes"], required != "[]" {
            // The POC only supports changing a password, not collecting additional profile attributes.
            throw CognitoPasswordError.accountAction
        }
        guard let session = response.Session, !session.isEmpty else { throw CloudAuthError.invalidResponse }
        return .newPassword(CognitoPasswordChallenge(session: session,
            username: response.ChallengeParameters?["USER_ID_FOR_SRP"] ?? username))
    }

    private func send(operation: String, body: [String: Any]) async throws -> Response {
        guard let url = URL(string: configuration.userPoolEndpoint) else { throw CloudAuthError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.setValue("AWSCognitoIdentityProviderService." + operation, forHTTPHeaderField: "X-Amz-Target")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CloudAuthError.invalidResponse }
        guard http.statusCode == 200 else {
            let failure = try? JSONDecoder().decode(Failure.self, from: data)
            let name = failure?.__type.split(separator: "#").last.map(String.init)
            switch name {
            case "NotAuthorizedException", "UserNotFoundException": throw CognitoPasswordError.incorrectCredentials
            case "TooManyRequestsException", "LimitExceededException": throw CognitoPasswordError.throttled
            case "InvalidPasswordException", "PasswordHistoryPolicyViolationException": throw CognitoPasswordError.passwordPolicy
            case "UserNotConfirmedException", "PasswordResetRequiredException": throw CognitoPasswordError.accountAction
            default: throw CloudAuthError.invalidResponse
            }
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private struct Failure: Decodable { let __type: String }
    private struct Response: Decodable {
        let AuthenticationResult: Authentication?
        let ChallengeName: String?
        let ChallengeParameters: [String: String]?
        let Session: String?
    }
    private struct Authentication: Decodable {
        let AccessToken: String
        let RefreshToken: String?
        let ExpiresIn: TimeInterval
        let TokenType: String
    }
}
