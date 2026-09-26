import SwiftUI

struct ImagePreviewCard: View {
    let asset: ImageAsset
    let editor: ReportEditorViewModel
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text(asset.fileName).font(.title2)
            ContentHeightScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.field) {
                    AssetImageView(asset: asset, editor: editor, maximumPixelSize: 2048,
                                   contentWidth: 560 - AppSpacing.dialogInset * 2)
                    Text(asset.altText.isEmpty ? "No alt text yet" : asset.altText)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Spacer()
                Button("Done", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("closeImagePreview")
            }
        }
        .floatingCard(width: 560)
    }
}
