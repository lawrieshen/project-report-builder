import Foundation

enum ExportFormat: String, CaseIterable, Identifiable {
    case png, html
    var id: Self { self }
    var title: String { rawValue.uppercased() }
    var mimeType: String { self == .png ? "image/png" : "text/html" }
}

enum ExportImageScale: String, CaseIterable, Identifiable {
    case standard, highResolution
    var id: Self { self }
    var title: String { self == .standard ? "Standard" : "High Resolution" }
    var factor: Double { self == .standard ? 1 : 2 }
}

enum ExportBackground: String, CaseIterable, Identifiable {
    case system, white, transparent
    var id: Self { self }
    var title: String { rawValue.capitalized }
}

enum ExportAppearance { case light, dark }

/// Freeze appearance and time when an export starts, independently of preview zoom.
struct ExportOptions: Equatable {
    var format: ExportFormat = .png
    var imageScale: ExportImageScale = .standard
    var background: ExportBackground = .white
    var appearance: ExportAppearance = .light
    var date: Date = .now
}

struct ExportResult {
    let data: Data
    let fileName: String
    let contentType: ExportFormat
}

enum ExportError: LocalizedError {
    case renderingFailed
    case unsupportedFormat
    case imageUnavailable(String)
    case reportTooLarge
    case clipboardFailed
    case sharingUnavailable

    var errorDescription: String? {
        switch self {
        case .renderingFailed: return "Unable to generate the report. Please try again."
        case .unsupportedFormat: return "This export format is not available."
        case .imageUnavailable(let name): return "Unable to load image \"\(name)\". Replace or remove it before exporting."
        case .reportTooLarge: return "The report is too large to export. Use Standard resolution or reduce its content."
        case .clipboardFailed: return "Unable to copy the report to the clipboard. Please try again."
        case .sharingUnavailable: return "Unable to open sharing. Close any existing share menu and try again."
        }
    }
}
