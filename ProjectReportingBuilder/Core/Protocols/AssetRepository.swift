import Foundation

/// Keep image bytes and file-system access outside the report model.
protocol AssetRepository: Sendable {
    /// Copy a selected image into managed storage.
    ///
    /// - Parameter url: The source image URL.
    /// - Returns: A reference to the managed image, not its bytes.
    /// - Throws: An error if validation or the managed copy fails.
    func importImage(from url: URL) async throws -> ImageAsset
    /// Remove a managed image file.
    ///
    /// - Parameter asset: The managed image to remove.
    /// - Throws: An error if the reference or removal cannot be processed.
    /// - Warning: Call only after confirming no saved report or recovery draft needs the file.
    func removeImage(_ asset: ImageAsset) async throws
    /// Load bounded image data for presentation.
    ///
    /// - Parameters:
    ///   - asset: The managed image reference.
    ///   - maximumPixelSize: The requested maximum thumbnail dimension in pixels.
    /// - Returns: Encoded image data.
    /// - Throws: An error if the image cannot be read or decoded.
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
