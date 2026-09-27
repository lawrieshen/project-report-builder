import SwiftUI

/// Import existing local projects explicitly; keep original files and report identities.
struct CloudMigrationView: View {
    @Bindable var store: CloudTransferStore

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            header
            localReports
            importStatus
        }
        .disabled(store.isBusy)
        .task { await store.refresh() }
    }

    @ViewBuilder
    private var header: some View {
        Text("Import Existing Local Reports").font(.headline)
        Text("Import saved reports and images into your cloud account. Original local files are kept. Existing cloud versions are checked before an update.")
            .font(.caption).foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var localReports: some View {
        if store.localProjects.isEmpty {
            Text("No local reports to import.").foregroundStyle(.secondary)
        }
        ForEach(store.localProjects) { project in
            HStack {
                VStack(alignment: .leading) {
                    Text(project.codeName)
                    if let result = store.migrationResults[project.id] {
                        Text(result).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("Import") { Task { await store.upload(id: project.id) } }
                    .accessibilityIdentifier("migrate_" + project.id.uuidString)
            }
        }
    }

    @ViewBuilder
    private var importStatus: some View {
        if store.isBusy { ProgressView("Importing…") }
        if let message = store.message { Text(message).font(.caption) }
        Button("Refresh") { Task { await store.refresh() } }
    }

}
