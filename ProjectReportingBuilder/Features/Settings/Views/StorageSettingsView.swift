import SwiftUI

struct StorageSettingsView: View {
    let store: ProjectFileStore
    let maintenance: RecoveryMaintenanceCoordinator
    @State private var showingClearConfirmation = false
    @State private var information: StorageInformation?
    @State private var error: String?
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text("Local Storage").font(.title2.bold())
            if let information {
                LabeledContent("Location") { Text(information.location.path).textSelection(.enabled) }
                LabeledContent("Projects", value: String(information.projectCount))
                LabeledContent("Assets", value: String(information.assetCount))
                LabeledContent("Recovery Drafts", value: String(information.recoveryCount))
                LabeledContent("Storage Used", value: ByteCountFormatter.string(fromByteCount: information.bytes, countStyle: .file))
                ForEach(information.warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) }
                Button("Open in Finder") { FinderService().reveal(information.location) }
            }
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Button("Refresh") { Task { await refresh() } }.disabled(isLoading)
                Button("Clear Recovery Drafts…", role: .destructive) { showingClearConfirmation = true }
                    .disabled(isLoading || maintenance.isClearing)
                    .accessibilityIdentifier("clearRecoveryDrafts")
                if isLoading || maintenance.isClearing { ProgressView().controlSize(.small) }
            }
            Text("Projects stay on this Mac. Save and autosave commit changes; recovery copies preserve unsaved edits separately.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(AppSpacing.pageInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { await refresh() }
        .confirmationDialog("Clear Recovery Drafts?", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
            Button("Clear", role: .destructive) { Task { await clearRecovery() } }
                .accessibilityIdentifier("confirmClearRecovery")
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Unsaved recovery data for all projects will be removed. Saved reports and images will remain. Current edits stay in memory; backups resume when you edit again.")
        }
    }

    private func clearRecovery() async {
        do {
            try await maintenance.clearRecovery(using: store)
            await refresh()
        } catch { self.error = error.localizedDescription }
    }

    private func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            information = try await store.information()
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}
