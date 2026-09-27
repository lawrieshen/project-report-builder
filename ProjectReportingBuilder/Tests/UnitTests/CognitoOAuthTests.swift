import Foundation
import Testing
@testable import Project_Report_Builder

@MainActor
struct CognitoOAuthTests {
    @Test func pkceMatchesRFC7636Example() {
        #expect(CognitoOAuth.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
                == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test func authorizationUsesPublicClientAndPKCE() throws {
        let url = try CognitoOAuth().authorizationURL(state: "test-state", verifier: "test-verifier")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items.contains(URLQueryItem(name: "code_challenge_method", value: "S256")))
        #expect(items.contains(URLQueryItem(name: "response_type", value: "code")))
        #expect(!items.contains { $0.name == "client_secret" })
    }

    @Test func callbackRejectsTamperingAndDuplicateParameters() throws {
        let oauth = CognitoOAuth()
        let valid = try #require(URL(string: "projectreportbuilder://auth/callback?state=expected&code=abc"))
        #expect(try oauth.code(from: valid, state: "expected") == "abc")
        let invalid = [
            "projectreportbuilder://other/callback?state=expected&code=abc",
            "projectreportbuilder://auth/logout?state=expected&code=abc",
            "projectreportbuilder://auth/callback?state=wrong&code=abc",
            "projectreportbuilder://auth/callback?state=expected&state=expected&code=abc",
            "projectreportbuilder://auth/callback?state=expected&code=a&code=b",
            "projectreportbuilder://auth/callback?state=expected&error=access_denied",
            "projectreportbuilder://auth/callback?state=expected&code="
        ]
        for value in invalid {
            let url = try #require(URL(string: value))
            #expect(throws: (any Error).self) { try oauth.code(from: url, state: "expected") }
        }
    }

    @Test func formEscapesReservedCharacters() {
        let data = CognitoOAuth.form(["code": "a+b&c=d e"])
        #expect(String(data: data, encoding: .utf8) == "code=a%2Bb%26c%3Dd%20e")
    }

    @Test func randomValuesAreIndependentAndURLSafe() throws {
        let first = try CognitoOAuth.randomValue()
        #expect(first.count == 43)
        #expect(first != (try CognitoOAuth.randomValue()))
        #expect(first.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" })
    }
}
