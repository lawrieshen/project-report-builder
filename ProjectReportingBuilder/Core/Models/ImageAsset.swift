import Foundation

/// Reference an app-managed image without embedding its bytes in the report.
struct ImageAsset: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var fileName: String
    var localReference: String
    var altText: String = ""
}
