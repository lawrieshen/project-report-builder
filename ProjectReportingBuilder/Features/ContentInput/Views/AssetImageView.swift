import SwiftUI

/// Load a bounded image through the repository, refreshing when its reference changes.
struct AssetImageView: View {
    let asset: ImageAsset
    let editor: ReportEditorViewModel
    var maximumPixelSize = 320
    var contentWidth: CGFloat? = nil
    @State private var image: NSImage?
    @State private var loadError: String?

    var body: some View {
        Group {
            imageContent
        }
        .task(id: asset.localReference) {
            image = nil
            loadError = nil
            do {
                let data = try await editor.imageData(for: asset, maximumPixelSize: maximumPixelSize)
                try Task.checkCancellation()
                guard let decoded = NSImage(data: data) else { throw AssetError.unreadableImage }
                image = decoded
            } catch is CancellationError {
                // Replacing an image or leaving its card cancels the previous load.
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: contentWidth,
                       height: contentWidth.map { width in
                           width * image.size.height / max(image.size.width, 1)
                       })
                .accessibilityLabel(asset.altText.isEmpty ? asset.fileName : asset.altText)
        } else if let loadError {
            Label(loadError, systemImage: "photo.badge.exclamationmark")
                .font(.caption)
        } else {
            ProgressView("Loading image…")
        }
    }
}
