import AppKit

/// Reveal application storage locations using the system file viewer.
@MainActor
struct FinderService {
    func reveal(_ directory: URL) { NSWorkspace.shared.activateFileViewerSelecting([directory]) }
}
