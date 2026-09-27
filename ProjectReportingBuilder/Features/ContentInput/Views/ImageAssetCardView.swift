import SwiftUI

struct ImageAssetCardView: View {
    let asset: ImageAsset
    @Bindable var editor: ReportEditorViewModel
    let canMoveUp: Bool
    let canMoveDown: Bool
    let preview: () -> Void
    let replace: () -> Void
    @FocusState private var editingAltText: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            imagePreview
            imageActions
            altTextField
        }
        .padding(AppSpacing.cardInset)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
        .contextMenu {
            Button("Preview", action: preview)
            Button("Replace Image", action: replace)
            Button("Edit Alt Text") { editingAltText = true }
            Button("Remove", role: .destructive) { editor.removeAsset(id: asset.id) }
        }
        .disabled(editor.isSaving || editor.isImporting)
    }

    @ViewBuilder
    private var imagePreview: some View {
        Button(action: preview) {
            AssetImageView(asset: asset, editor: editor)
                .frame(maxWidth: .infinity)
                .frame(height: 110)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Preview " + asset.fileName)
    }

    @ViewBuilder
    private var imageActions: some View {
        HStack {
            Text(asset.fileName).lineLimit(2)
            Spacer()
            Menu {
                Button("Preview", action: preview)
                Button("Replace Image", action: replace)
                Button("Edit Alt Text") { editingAltText = true }
                Button("Move Up") { editor.moveAsset(id: asset.id, offset: -1) }
                    .disabled(!canMoveUp)
                Button("Move Down") { editor.moveAsset(id: asset.id, offset: 1) }
                    .disabled(!canMoveDown)
                Divider()
                Button("Remove", role: .destructive) { editor.removeAsset(id: asset.id) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Image actions for " + asset.fileName)
            .accessibilityIdentifier("assetActions." + asset.fileName)
        }
    }

    @ViewBuilder
    private var altTextField: some View {
        TextField("Alt text", text: Binding(
            get: { asset.altText },
            set: { editor.updateAltText(assetID: asset.id, altText: $0) }
        ), axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .focused($editingAltText)
        .accessibilityLabel("Alt text for " + asset.fileName)
        .accessibilityIdentifier("assetAltText." + asset.fileName)
    }
}
