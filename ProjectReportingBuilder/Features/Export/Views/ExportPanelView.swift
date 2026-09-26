import SwiftUI

struct ExportPanelView: View {
    @Bindable var viewModel: ExportViewModel
    let model: ReportPreviewModel
    let validation: ReportValidationModel
    let reviewIssues: () -> Void
    let onDismiss: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            header
            ViewThatFits(in: .vertical) {
                content.fixedSize(horizontal: false, vertical: true)
                ScrollView { content }
            }
        }
        .floatingCard(width: 480)
    }

    private var header: some View {
        HStack {
            Text("Export / Share").font(.title2)
            Spacer()
            Button("Close", action: onDismiss)
                .disabled(viewModel.isBusy)
                .accessibilityIdentifier("closeExport")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text("Export the current report, including unsaved changes.")
                .font(.callout).foregroundStyle(.secondary)
            options
            if viewModel.requiresConfirmation, let report = viewModel.accessibilityReport {
                ReportValidationExportWarningView(issueCount: report.issues.count,
                    review: {
                        viewModel.cancelPendingExport()
                        reviewIssues()
                    }, proceed: { Task { await viewModel.exportAnyway() } },
                    cancel: viewModel.cancelPendingExport)
            } else {
                actions
            }
            feedback
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            Picker("Format", selection: $viewModel.selectedFormat) {
                ForEach(ExportFormat.allCases) { Text($0.title).tag($0) }
            }
            .accessibilityIdentifier("exportFormat")
            if viewModel.selectedFormat == .png {
                Picker("Size", selection: $viewModel.imageScale) {
                    ForEach(ExportImageScale.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("exportScale")
                Picker("Background", selection: $viewModel.background) {
                    ForEach(ExportBackground.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("exportBackground")
                Text("Standard is 720 pixels wide; High Resolution doubles the dimensions. Transparent uses dark text without a card background.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(viewModel.isBusy || viewModel.requiresConfirmation)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            HStack {
                Button("Copy Image") { run(.copy) }.accessibilityIdentifier("copyExport")
                Button("Save to Finder…") { run(.save) }.accessibilityIdentifier("saveExport")
                Button("Share…") { run(.share) }.accessibilityIdentifier("shareExport")
            }
            if viewModel.selectedFormat == .html {
                Text("Copy Image always copies PNG. Save and Share use HTML.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .disabled(viewModel.isBusy)
    }

    @ViewBuilder
    private var feedback: some View {
        if viewModel.isBusy {
            ProgressView(viewModel.isCheckingAccessibility && !viewModel.isExporting
                         ? "Validating report…" : viewModel.progressMessage)
        } else if let error = viewModel.errorMessage {
            Text(error).floatingCardError()
            if let action = viewModel.lastAction { Button("Retry") { run(action) } }
        } else if let message = viewModel.successMessage {
            Label(message, systemImage: "checkmark.circle")
                .accessibilityIdentifier("exportSuccess")
        }
    }

    private func run(_ action: ExportAction) {
        let appearance: ExportAppearance = colorScheme == .dark ? .dark : .light
        Task { await viewModel.request(action, model: model, validation: validation, appearance: appearance) }
    }
}
