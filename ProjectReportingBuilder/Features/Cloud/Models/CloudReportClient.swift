import Foundation

protocol CloudReportServing {
    func list(after: UUID?) async throws -> CloudReportPage
    func get(id: UUID) async throws -> CloudReport
    func save(id: UUID, revision: Int64, content: CloudReportContent) async throws -> CloudReport
}

struct CloudReportPage: Decodable {
    var items: [CloudReport]
    var nextCursor: UUID?
}

/// Send access tokens only to the configured report API; never persist them here.
final class CloudReportClient: CloudReportServing {
    private let account: CloudAccountStore
    private let session: URLSession
    private let endpoint = "https://ic1fsr0eg6.execute-api.ap-southeast-2.amazonaws.com"

    init(account: CloudAccountStore, session: URLSession = .shared) {
        self.account = account
        self.session = session
    }

    func list(after: UUID?) async throws -> CloudReportPage {
        var path = "/reports?limit=10"
        if let after { path += "&after=" + after.uuidString.lowercased() }
        return try await request(path: path, method: "GET", body: nil)
    }

    func get(id: UUID) async throws -> CloudReport {
        try await request(path: "/reports/" + id.uuidString.lowercased(), method: "GET", body: nil)
    }

    func save(id: UUID, revision: Int64, content: CloudReportContent) async throws -> CloudReport {
        struct SaveRequest: Encodable {
            let schemaVersion = 2
            let expectedRevision: Int64
            let report: CloudReportContent
        }
        let data = try JSONEncoder().encode(SaveRequest(expectedRevision: revision, report: content))
        return try await request(path: "/reports/" + id.uuidString.lowercased(), method: "PUT", body: data)
    }

    func uploadURL(projectID: UUID, asset: CloudImageAsset) async throws -> CloudAssetTransfer {
        try await request(path: "/reports/" + projectID.uuidString.lowercased() + "/assets/upload",
                          method: "POST", body: JSONEncoder().encode(asset))
    }

    func downloadURL(projectID: UUID, assetID: String) async throws -> CloudAssetTransfer {
        guard let id = UUID(uuidString: assetID) else { throw CloudTransferError.invalidResponse }
        return try await request(path: "/reports/" + projectID.uuidString.lowercased() + "/assets/" + id.uuidString.lowercased(),
                                 method: "GET", body: nil)
    }

    private func request<Response: Decodable>(path: String, method: String, body: Data?) async throws -> Response {
        guard let url = URL(string: endpoint + path) else { throw CloudTransferError.invalidResponse }
        let token = try await account.validAccessToken()
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 35
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw CloudTransferError.invalidResponse }
        switch response.statusCode {
        case 200: return try JSONDecoder().decode(Response.self, from: data)
        case 401: throw CloudTransferError.signedOut
        case 403: throw CloudTransferError.forbidden
        case 500...599: throw CloudTransferError.serverUnavailable
        case 409: throw CloudTransferError.conflict
        default: throw CloudTransferError.rejected
        }
    }
}
