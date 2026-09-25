import AppKit

/// Keep each share in its own directory until its native service finishes.
struct ShareFileStore {
    let root: URL

    init(root: URL = FileManager.default.temporaryDirectory.appendingPathComponent("ReportShareExports")) {
        self.root = root
    }

    func create(_ result: ExportResult) throws -> URL {
        let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let base = (result.fileName as NSString).deletingPathExtension
        let url = directory.appendingPathComponent(ExportFileName.fileName(base, format: result.contentType))
        do {
            try result.data.write(to: url, options: .atomic)
            return url
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    func remove(_ url: URL) {
        let directory = url.deletingLastPathComponent()
        guard directory.deletingLastPathComponent().standardizedFileURL == root.standardizedFileURL,
              UUID(uuidString: directory.lastPathComponent) != nil else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    /// Recover leftovers from interrupted shares on a later launch, never active shares.
    func removeExpired(before cutoff: Date) {
        guard let directories = try? FileManager.default.contentsOfDirectory(at: root,
                    includingPropertiesForKeys: [.creationDateKey, .isDirectoryKey]) else { return }
        for directory in directories {
            guard UUID(uuidString: directory.lastPathComponent) != nil,
                  let values = try? directory.resourceValues(forKeys: [.creationDateKey, .isDirectoryKey]),
                  values.isDirectory == true, let created = values.creationDate, created < cutoff else { continue }
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

@MainActor
final class MacShareService: NSObject, ReportSharing, NSSharingServicePickerDelegate, NSSharingServiceDelegate {
    static let shared = MacShareService()
    private let files: ShareFileStore
    private var picker: NSSharingServicePicker?
    private var activeFile: URL?
    private var activeService: NSSharingService?
    private let anchorView: () -> NSView?

    init(files: ShareFileStore = ShareFileStore(), anchorView: @escaping () -> NSView? = { NSApp.keyWindow?.contentView }) {
        self.files = files
        self.anchorView = anchorView
        super.init()
        files.removeExpired(before: Date.now.addingTimeInterval(-86_400))
    }

    func share(result: ExportResult) throws {
        guard picker == nil, let view = anchorView(), view.window != nil else { throw ExportError.sharingUnavailable }
        let url = try files.create(result)
        activeFile = url
        let picker = NSSharingServicePicker(items: [url])
        picker.delegate = self
        self.picker = picker
        picker.show(relativeTo: CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1),
                    of: view, preferredEdge: .maxY)
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker,
                              delegateFor sharingService: NSSharingService) -> (any NSSharingServiceDelegate)? {
        self
    }

    func sharingServicePicker(_ sharingServicePicker: NSSharingServicePicker, didChoose service: NSSharingService?) {
        activeService = service
        if service == nil { finish() }
    }

    func sharingService(_ sharingService: NSSharingService, didShareItems items: [Any]) { finish() }

    func sharingService(_ sharingService: NSSharingService, didFailToShareItems items: [Any], error: any Error) {
        finish()
        guard (error as NSError).code != NSUserCancelledError else { return }
        if let window = NSApp.mainWindow { NSAlert(error: error).beginSheetModal(for: window) }
    }

    private func finish() {
        if let activeFile { files.remove(activeFile) }
        activeFile = nil
        picker = nil
        activeService = nil
    }
}
