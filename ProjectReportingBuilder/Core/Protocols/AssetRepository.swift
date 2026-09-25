import Foundation

/// Keep image bytes and file-system access outside the report model.
protocol AssetRepository: Sendable {
    func importImage(from url: URL) async throws -> ImageAsset
    func removeImage(_ asset: ImageAsset) async throws
    func thumbnailData(for asset: ImageAsset, maximumPixelSize: Int) async throws -> Data
}

enum AssetError: LocalizedError {
    case unsupportedType
    case unreadableImage
    case tooLarge(Int)
    case invalidReference

    var errorDescription: String? {
        switch self {
        case .unsupportedType: return "Unsupported image type. Choose PNG, JPEG, or HEIC."
        case .unreadableImage: return "This image could not be read."
        case .tooLarge(let bytes): return "Choose an image smaller than \(bytes / 1_048_576) MB."
        case .invalidReference: return "The image reference is invalid."
        }
    }
}
