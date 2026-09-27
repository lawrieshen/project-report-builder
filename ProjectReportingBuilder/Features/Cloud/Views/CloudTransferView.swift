import SwiftUI

struct CloudTransferView: View {
    @Bindable var store: CloudTransferStore
    @State private var selectedProject: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Divider()
            Text("Cloud Reports").font(.headline)
            Text("Upload the last saved version. Images are included (PNG, JPEG, HEIC; up to 10 images, 20 MB each and 50 MB total). Downloads create new local projects.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Picker("Local project", selection: $selectedProject) {
                    Text("Choose a project").tag(nil as UUID?)
                    ForEach(store.localProjects) { project in
                        Text(project.codeName).tag(Optional(project.id))
                    }
                }
                Button("Upload Saved Version") {
                    if let selectedProject { Task { await store.upload(id: selectedProject) } }
                }
                .disabled(selectedProject == nil)
            }
            HStack {
                Button("Refresh Reports") { Task { await store.refresh() } }
                if store.isBusy { ProgressView().controlSize(.small) }
            }
            if let message = store.message { Text(message).font(.callout).textSelection(.enabled) }
            ForEach(store.cloudReports) { report in
                HStack {
                    VStack(alignment: .leading) {
                        Text(report.report.codeName)
                        Text("\(report.report.lineOfBusiness) · Version \(report.revision)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Download Copy") { Task { await store.download(id: report.id) } }
                }
            }
            if store.nextCursor != nil {
                Button("Load More") { Task { await store.loadMore() } }
            }
        }
        .disabled(store.isBusy)
        .task { await store.refresh() }
    }
}
