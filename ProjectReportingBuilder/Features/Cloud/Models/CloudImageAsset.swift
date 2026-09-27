import Foundation
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

struct CloudImageAsset: Codable, Equatable {
    var id: String
    var fileName: String
    var altText: String
    var contentType: String
    var byteCount: Int
    var sha256: String

    init(asset: ImageAsset, data: Data) throws {
        id = asset.id.uuidString.lowercased()
        fileName = asset.fileName
        altText = asset.altText
        contentType = try Self.imageType(data)
        byteCount = data.count
        sha256 = Self.digest(data)
        try validateMetadata()
    }

    func validateMetadata() throws {
        guard UUID(uuidString: id) != nil, !fileName.isEmpty, fileName.count <= 255,
              !fileName.contains("/"), !fileName.contains("\\"), altText.count <= 2000,
              ["image/png", "image/jpeg", "image/heic"].contains(contentType),
              byteCount > 0, byteCount <= 20 * 1_048_576,
              sha256.count == 64, sha256.allSatisfy({ "0123456789abcdef".contains($0) }) else {
            throw CloudTransferError.invalidResponse
        }
    }

    func validate(_ data: Data) throws {
        try validateMetadata()
        guard data.count == byteCount, Self.digest(data) == sha256,
              try Self.imageType(data) == contentType else { throw CloudTransferError.invalidResponse }
    }

    func localAsset() throws -> ImageAsset {
        try validateMetadata()
        guard let id = UUID(uuidString: id) else { throw CloudTransferError.invalidResponse }
        let suffix = contentType == "image/png" ? "png" : contentType == "image/jpeg" ? "jpg" : "heic"
        return ImageAsset(id: id, fileName: fileName, localReference: id.uuidString + "." + suffix, altText: altText)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func imageType(_ data: Data) throws -> String {
        guard !data.isEmpty, data.count <= 20 * 1_048_576 else { throw AssetError.tooLarge(20 * 1_048_576) }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let identifier = CGImageSourceGetType(source) else { throw AssetError.unreadableImage }
        let type = UTType(identifier as String)
        let mime: String
        switch type {
        case .png: mime = "image/png"
        case .jpeg: mime = "image/jpeg"
        case .heic: mime = "image/heic"
        default: throw AssetError.unsupportedType
        }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                       kCGImageSourceThumbnailMaxPixelSize: 64]
        guard CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) != nil else {
            throw AssetError.unreadableImage
        }
        return mime
    }
}

struct CloudAssetTransfer: Decodable {
    let url: URL
    let headers: [String: String]
}

protocol CloudImageTransferring {
    func uploadImages(for project: ProjectReport) async throws -> [CloudImageAsset]
    func importCopy(of report: CloudReport) async throws -> ProjectReport
}

/// Verify image bytes and publish a local copy only after every download completes.
final class CloudImageTransfer: CloudImageTransferring, CloudProjectImages {
    private let files: ProjectFileStore
    private let client: any CloudImageURLServing
    private let session: URLSession

    init(files: ProjectFileStore, client: any CloudImageURLServing) {
        self.files = files
        self.client = client
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 90
        session = URLSession(configuration: configuration, delegate: CloudImageSessionDelegate(), delegateQueue: nil)
    }

    func uploadImages(for project: ProjectReport) async throws -> [CloudImageAsset] {
        try await upload(project: project, previous: nil)
    }

    func upload(project: ProjectReport, previous: CloudReport?) async throws -> [CloudImageAsset] {
        let assets = project.card?.assets ?? []
        guard assets.count <= 10 else { throw CloudTransferError.imageLimit }
        var result: [CloudImageAsset] = []
        var total = 0
        for asset in assets {
            try Task.checkCancellation()
            let data = try await files.cloudImageData(asset, projectID: project.id)
            total += data.count
            guard total <= 50 * 1_048_576 else { throw CloudTransferError.imageLimit }
            let metadata = try CloudImageAsset(asset: asset, data: data)
            if (previous?.report.assets ?? []).contains(where: {
                $0.sha256 == metadata.sha256 && $0.byteCount == metadata.byteCount && $0.contentType == metadata.contentType
            }) {
                result.append(metadata)
                continue
            }
            let transfer = try await client.uploadURL(projectID: project.id, asset: metadata)
            let request = try signedRequest(transfer, method: "PUT")
            let (_, response) = try await session.upload(for: request, from: data)
            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                throw CloudTransferError.imageTransferFailed
            }
            result.append(metadata)
        }
        return result
    }

    func importCopy(of report: CloudReport) async throws -> ProjectReport {
        let assets = report.report.assets ?? []
        guard assets.count <= 10 else { throw CloudTransferError.imageLimit }
        var images: [UUID: Data] = [:]
        var total = 0
        for asset in assets {
            try asset.validateMetadata()
            total += asset.byteCount
            guard total <= 50 * 1_048_576 else { throw CloudTransferError.imageLimit }
            let transfer = try await client.downloadURL(projectID: report.id, assetID: asset.id)
            let (temporary, response) = try await session.download(for: signedRequest(transfer, method: "GET"))
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                throw CloudTransferError.imageTransferFailed
            }
            let size = try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize
            guard size == asset.byteCount else { throw CloudTransferError.invalidResponse }
            let data = try Data(contentsOf: temporary)
            try asset.validate(data)
            let local = try asset.localAsset()
            guard images[local.id] == nil else { throw CloudTransferError.invalidResponse }
            images[local.id] = data
        }
        try Task.checkCancellation()
        let copy = try report.report.localCopy()
        try await files.importCloudCopy(copy, images: images)
        return copy
    }

    /// Hydrate only missing or invalid image bytes; report snapshots remain cache data.
    func cache(report: CloudReport, project: ProjectReport) async throws {
        let metadata = report.report.assets ?? []
        guard metadata.count <= 10, metadata.reduce(0, { $0 + $1.byteCount }) <= 50 * 1_048_576 else {
            throw CloudTransferError.imageLimit
        }
        try await files.save(project)
        for asset in metadata {
            try Task.checkCancellation()
            let local = try asset.localAsset()
            if let data = try? await files.cloudImageData(local, projectID: project.id),
               (try? asset.validate(data)) != nil { continue }
            let transfer = try await client.downloadURL(projectID: project.id, assetID: asset.id)
            let (temporary, response) = try await session.download(for: signedRequest(transfer, method: "GET"))
            defer { try? FileManager.default.removeItem(at: temporary) }
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  try temporary.resourceValues(forKeys: [.fileSizeKey]).fileSize == asset.byteCount else {
                throw CloudTransferError.imageTransferFailed
            }
            let data = try Data(contentsOf: temporary)
            try asset.validate(data)
            try Task.checkCancellation()
            try await files.writeAsset(data, asset: local, projectID: project.id)
        }
    }

    func copyCachedImages(from id: UUID, to project: ProjectReport) async throws {
        try await files.save(project)
        for asset in project.card?.assets ?? [] {
            let data = try await files.cloudImageData(asset, projectID: id)
            try await files.writeAsset(data, asset: asset, projectID: project.id)
        }
    }

    private func signedRequest(_ transfer: CloudAssetTransfer, method: String) throws -> URLRequest {
        // Never send account tokens to S3 or follow arbitrary destinations from a response.
        guard transfer.url.scheme == "https",
              transfer.url.host == "prb-dev-assets-543123648742-ap-southeast-2.s3.ap-southeast-2.amazonaws.com" else {
            throw CloudTransferError.invalidResponse
        }
        var request = URLRequest(url: transfer.url)
        request.httpMethod = method
        for (name, value) in transfer.headers {
            guard ["content-type", "content-length", "x-amz-checksum-sha256"].contains(name.lowercased()) else {
                throw CloudTransferError.invalidResponse
            }
            request.setValue(value, forHTTPHeaderField: name)
        }
        return request
    }
}

/// Keep signed requests on the validated S3 endpoint.
private final class CloudImageSessionDelegate: NSObject, URLSessionTaskDelegate {
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
protocol CloudImageURLServing {
    func uploadURL(projectID: UUID, asset: CloudImageAsset) async throws -> CloudAssetTransfer
    func downloadURL(projectID: UUID, assetID: String) async throws -> CloudAssetTransfer
}

extension CloudReportClient: CloudImageURLServing { }
