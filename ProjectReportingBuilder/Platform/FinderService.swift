import AppKit

@MainActor
struct FinderService {
    func reveal(_ directory: URL) { NSWorkspace.shared.activateFileViewerSelecting([directory]) }
}
