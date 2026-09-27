import Foundation
import CryptoKit
import Security

/// Keep the public development client settings together; these are not secrets.
struct CognitoConfiguration {
    let domain = "https://prb-dev-543123648742-ap-southeast-2.auth.ap-southeast-2.amazoncognito.com"
    let userPoolEndpoint = "https://cognito-idp.ap-southeast-2.amazonaws.com/"
    let clientID = "50140nj121i4sbsra4m8o37cqq"
    let callback = "projectreportbuilder://auth/callback"
}

enum CloudAuthError: LocalizedError {
    case invalidResponse, invalidCallback, expiredSession, keychain(OSStatus), randomGeneration
    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The sign-in service returned an unexpected response. Please try again."
        case .invalidCallback: "The sign-in response could not be verified. Please sign in again."
        case .expiredSession: "Your cloud session has expired. Please sign in again."
        case .keychain: "Unable to access cloud credentials in Keychain."
        case .randomGeneration: "Unable to start a secure sign-in session."
        }
    }
}

struct CognitoOAuth {
    let configuration = CognitoConfiguration()

    static func randomValue() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw CloudAuthError.randomGeneration
        }
        return base64URL(Data(bytes))
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func form(_ values: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let text = values.sorted { $0.key < $1.key }.map { key, value in
            "\(key.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&")
        return Data(text.utf8)
    }

    func authorizationURL(state: String, verifier: String) throws -> URL {
        guard var components = URLComponents(string: configuration.domain + "/oauth2/authorize") else {
            throw CloudAuthError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.callback),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email reports/read reports/write"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: Self.challenge(for: verifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let url = components.url else { throw CloudAuthError.invalidResponse }
        return url
    }

    func code(from url: URL, state: String) throws -> String {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "projectreportbuilder", parts.host == "auth", parts.path == "/callback",
              parts.port == nil, parts.user == nil, parts.password == nil, parts.fragment == nil else {
            throw CloudAuthError.invalidCallback
        }
        let items = parts.queryItems ?? []
        let states = items.filter { $0.name == "state" }
        let codes = items.filter { $0.name == "code" }
        guard states.count == 1, states.first?.value == state,
              !items.contains(where: { $0.name == "error" }),
              codes.count == 1, let code = codes.first?.value, !code.isEmpty else {
            throw CloudAuthError.invalidCallback
        }
        return code
    }
}

struct CognitoTokens: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: TimeInterval
    let token_type: String
}

protocol CognitoTokenServing {
    func tokens(fields: [String: String]) async throws -> CognitoTokens
    func revoke(_ refreshToken: String) async throws
}

struct CognitoTokenClient: CognitoTokenServing {
    var session: URLSession = .shared
    let configuration = CognitoConfiguration()

    func tokens(fields: [String: String]) async throws -> CognitoTokens {
        if fields["grant_type"] == "refresh_token", let refresh = fields["refresh_token"] {
            return try await CognitoPasswordClient(session: session).refresh(refresh)
        }
        let data = try await post(path: "/oauth2/token", fields: fields)
        let tokens = try JSONDecoder().decode(CognitoTokens.self, from: data)
        guard !tokens.access_token.isEmpty, tokens.expires_in > 0,
              tokens.token_type.lowercased() == "bearer" else { throw CloudAuthError.invalidResponse }
        return tokens
    }

    func revoke(_ refreshToken: String) async throws {
        _ = try await post(path: "/oauth2/revoke", fields: ["token": refreshToken])
    }

    private func post(path: String, fields: [String: String]) async throws -> Data {
        guard let url = URL(string: configuration.domain + path) else { throw CloudAuthError.invalidResponse }
        var fields = fields
        fields["client_id"] = configuration.clientID
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = CognitoOAuth.form(fields)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw CloudAuthError.invalidResponse }
        guard response.statusCode == 200 else {
            let error = try? JSONDecoder().decode(OAuthFailure.self, from: data)
            if error?.error == "invalid_grant" { throw CloudAuthError.expiredSession }
            throw CloudAuthError.invalidResponse
        }
        return data
    }

    private struct OAuthFailure: Decodable { let error: String }
}
