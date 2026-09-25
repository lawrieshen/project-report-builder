import SwiftUI

struct ImagePreviewCard: View {
    let asset: ImageAsset
    let editor: ReportEditorViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text(asset.fileName).font(.title2)
            AssetImageView(asset: asset, editor: editor, maximumPixelSize: 2048)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(asset.altText.isEmpty ? "No alt text yet" : asset.altText)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Done", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("closeImagePreview")
            }
        }
        .floatingCard(width: 560, maxHeight: .infinity)
    }
}
