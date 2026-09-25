import SwiftUI

struct LivePreviewView: View {
    let model: ReportPreviewModel
    let loadImage: (ImageAsset) async throws -> Data
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var viewModel = LivePreviewViewModel()
    @State private var images: [String: PreviewImageState] = [:]
    @State private var viewport = CGSize.zero
    @State private var cardHeight: CGFloat = 1

    private var cardWidth: CGFloat {
        guard viewModel.isFitting, viewport.width > 0 else { return ReportCardStyle.standardWidth }
        return min(ReportCardStyle.standardWidth,
                   max(ReportCardStyle.minimumWidth, viewport.width - ReportCardStyle.canvasInset * 2))
    }

    private var displayedZoom: Double {
        viewModel.displayedZoom(
            available: CGSize(width: max(1, viewport.width - ReportCardStyle.canvasInset * 2),
                              height: max(1, viewport.height - ReportCardStyle.canvasInset * 2)),
            content: CGSize(width: cardWidth, height: cardHeight))
    }

    private var colorScheme: ColorScheme {
        switch viewModel.appearance {
        case .system: return systemColorScheme
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        VStack(spacing: AppSpacing.field) {
            header
            controls
            Divider()
            GeometryReader { geometry in
                canvas(size: geometry.size)
                    .onAppear { viewport = geometry.size }
                    .onChange(of: geometry.size) { _, size in viewport = size }
            }
        }
        .task(id: model.assets.map(\.localReference)) {
            await loadImages()
        }
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Text("Live Preview").font(.title2)
            Spacer()
            Button("Done", action: onDismiss)
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("closeLivePreview")
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: AppSpacing.inline) {
            Button {
                viewModel.zoomOut(from: displayedZoom)
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .accessibilityLabel("Zoom Out")
            .disabled(displayedZoom <= 0.5)
            Text(displayedZoom.formatted(.percent.precision(.fractionLength(0))))
                .monospacedDigit()
                .accessibilityIdentifier("previewZoom")
            Button {
                viewModel.zoomIn(from: displayedZoom)
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .accessibilityLabel("Zoom In")
            .disabled(displayedZoom >= 2)
            Button("Actual Size") { viewModel.resetZoom() }
            Button("Fit") { viewModel.fit() }
            Spacer()
            Picker("Appearance", selection: $viewModel.appearance) {
                ForEach(PreviewAppearance.allCases) { appearance in
                    Text(appearance.title).tag(appearance)
                }
            }
            .fixedSize()
            .accessibilityIdentifier("previewAppearance")
        }
    }

    private func canvas(size: CGSize) -> some View {
        ScrollView([.horizontal, .vertical]) {
            // Account for the transformed dimensions so zoomed content remains scrollable.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                ReportCardView(model: model, images: images, now: context.date)
                    .frame(width: cardWidth)
                    .fixedSize(horizontal: false, vertical: true)
                    .background {
                        GeometryReader { geometry in
                            Color.clear
                                .onAppear { updateCardHeight(geometry.size.height) }
                                .onChange(of: geometry.size.height) { _, height in updateCardHeight(height) }
                        }
                    }
                    .scaleEffect(displayedZoom, anchor: .topLeading)
                    .frame(width: cardWidth * displayedZoom, height: cardHeight * displayedZoom, alignment: .topLeading)
            }
            .padding(ReportCardStyle.canvasInset)
            .frame(minWidth: size.width, minHeight: size.height, alignment: .top)
        }
        .background(Color(nsColor: .underPageBackgroundColor))
        .environment(\.colorScheme, colorScheme)
        .clipShape(RoundedRectangle(cornerRadius: ReportCardStyle.tileRadius))
        .accessibilityIdentifier("previewCanvas")
    }

    // Measure inside TimelineView, whose boundary does not reliably forward preferences.
    private func updateCardHeight(_ height: CGFloat) {
        if height > 0 && abs(cardHeight - height) > 0.5 { cardHeight = height }
    }

    private func loadImages() async {
        let references = Set(model.assets.map(\.localReference))
        images = images.filter { references.contains($0.key) }
        for asset in model.assets {
            if images[asset.localReference] != nil { continue }
            do {
                let data = try await loadImage(asset)
                try Task.checkCancellation()
                guard let image = NSImage(data: data) else { throw AssetError.unreadableImage }
                images[asset.localReference] = .loaded(image)
            } catch is CancellationError {
                return
            } catch {
                images[asset.localReference] = .unavailable
            }
        }
    }
}
