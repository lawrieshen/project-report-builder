import Foundation

/// Keep navigation metadata separate from saved report data.
nonisolated struct AppSessionState: Codable, Equatable {
    var lastOpenedProjectID: UUID?
}
