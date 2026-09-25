import SwiftUI

struct ReportPreviewAssetsView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let style = ReportAccessibilityStyle.canonical
    private var palette: ReportPalette { style.palette(colorScheme) }
    let assets: [ImageAsset]
    let images: [String: PreviewImageState]

    private var columns: [GridItem] {
        if assets.count == 1 { return [GridItem(.flexible())] }
        return [GridItem(.adaptive(minimum: ReportCardStyle.imageMinimumWidth), spacing: AppSpacing.gridGap)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            ReportSectionHeading(section: .supportingContent)
            LazyVGrid(columns: columns, spacing: AppSpacing.gridGap) {
                ForEach(assets) { asset in
                    assetImage(asset)
                }
            }
        }
    }

    @ViewBuilder
    private func assetImage(_ asset: ImageAsset) -> some View {
        Group {
            switch images[asset.localReference] {
            case .loaded(let image):
                Image(nsImage: image).resizable().scaledToFit()
                    .accessibilityLabel(asset.altText.isEmpty ? asset.fileName : asset.altText)
            case .unavailable:
                Label("Image unavailable: " + asset.fileName, systemImage: "photo.badge.exclamationmark")
                    .font(.system(size: style.captionSize))
            case nil:
                ProgressView("Loading " + asset.fileName)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: ReportCardStyle.imageHeight)
        .background(palette.tile.color)
        .clipShape(RoundedRectangle(cornerRadius: ReportCardStyle.tileRadius))
    }
}
