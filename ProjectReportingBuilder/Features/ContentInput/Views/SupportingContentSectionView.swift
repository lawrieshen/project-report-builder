import SwiftUI
import UniformTypeIdentifiers

struct SupportingContentSectionView: View {
    @Bindable var editor: ReportEditorViewModel
    let preview: (ImageAsset) -> Void
    @State private var showingImporter = false
    @State private var replacingID: UUID?
    @State private var isDropTargeted = false

    private var assets: [ImageAsset] { editor.draft?.assets ?? [] }
    private var isBusy: Bool { editor.isSaving || editor.isImporting }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            sectionHeader
            dropZone
            if editor.isImporting { ProgressView("Importing images…") }
            if let error = editor.assetError { Text(error).floatingCardError() }
            if let warning = editor.cleanupWarning { Text(warning).foregroundStyle(.secondary) }
            imageGrid
        }
        .fileImporter(isPresented: $showingImporter,
                      allowedContentTypes: [.png, .jpeg, .heic],
                      allowsMultipleSelection: replacingID == nil) { result in
            let replacement = replacingID
            replacingID = nil
            switch result {
            case .success(let urls):
                Task { await editor.importImages(from: urls, replacing: replacement) }
            case .failure(let error): editor.assetError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private var sectionHeader: some View {
        HStack {
            Text("Supporting Content").font(.title3.bold())
            Spacer()
            Button("Choose Images") {
                replacingID = nil
                showingImporter = true
            }
            .disabled(isBusy)
            .accessibilityIdentifier("chooseImages")
        }
    }

    @ViewBuilder
    private var dropZone: some View {
        VStack(spacing: AppSpacing.inline) {
            Image(systemName: "photo.on.rectangle.angled")
            Text("Drop images here")
            Text("PNG · JPEG · HEIC · up to 20 MB per image")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 90)
        .background(isDropTargeted ? Color.accentColor.opacity(0.15) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1, dash: [5]))
        }
        .accessibilityIdentifier("imageDropZone")
        .dropDestination(for: URL.self) { urls, _ in
            guard !isBusy, !urls.isEmpty else { return false }
            Task { await editor.importImages(from: urls) }
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    @ViewBuilder
    private var imageGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: AppSpacing.gridGap)],
                  spacing: AppSpacing.gridGap) {
            ForEach(Array(assets.enumerated()), id: \.element.id) { index, asset in
                ImageAssetCardView(asset: asset, editor: editor, canMoveUp: index > 0,
                                   canMoveDown: index < assets.count - 1,
                                   preview: { preview(asset) },
                                   replace: {
                    replacingID = asset.id
                    showingImporter = true
                })
            }
        }
    }
}
