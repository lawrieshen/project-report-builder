import SwiftUI

/// Show report content only after the API accepts the account session.
struct CloudRootView: View {
    let environment: AppEnvironment
    let onSession: (AppSessionStore) -> Void
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        Group {
            if let workspace = environment.workspace, environment.cloudAccount.isSignedIn {
                ContentView(repository: workspace.repository, assetFactory: workspace.assets,
                    recoveryRepository: LocalDraftRecoveryRepository(store: workspace.files),
                    settings: environment.settings, session: workspace.session, maintenance: workspace.maintenance)
                    .id(environment.cloudAccount.sessionID)
            } else {
                VStack(spacing: AppSpacing.section) {
                    Text("Project Reporting Builder").font(.largeTitle.bold())
                    Text("Sign in to open your cloud reports.").foregroundStyle(.secondary)
                    if loading || environment.cloudAccount.isBusy { ProgressView() }
                    if let message = error ?? environment.cloudAccount.message {
                        Text(message).foregroundStyle(.secondary)
                    }
                    if environment.cloudAccount.isSignedIn {
                        Button("Retry") { Task { await openWorkspace() } }.disabled(loading)
                        Button("Sign Out") { Task { await environment.cloudAccount.signOut() } }
                    } else {
                        Button("Sign In") { Task { await environment.cloudAccount.signIn() } }
                            .disabled(environment.cloudAccount.isBusy)
                            .accessibilityIdentifier("cloudSignIn")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .disabled(environment.cloudAccount.isBusy)
        .frame(minWidth: 760, minHeight: 400)
        .task { await environment.cloudAccount.restore() }
        .task(id: environment.cloudAccount.sessionID) { await openWorkspace() }
    }

    private func openWorkspace() async {
        environment.workspace?.repository.invalidate()
        environment.workspace = nil
        environment.cloudTransfers.clear()
        loading = false
        guard environment.cloudAccount.isSignedIn else { return }
        let session = environment.cloudAccount.sessionID
        loading = true
        error = nil
        defer { if environment.cloudAccount.sessionID == session { loading = false } }
        do {
            let client = CloudReportClient(account: environment.cloudAccount)
            _ = try await client.list(after: nil)
            try Task.checkCancellation()
            guard environment.cloudAccount.isSignedIn, environment.cloudAccount.sessionID == session else { return }
            let workspace = try CloudWorkspace(root: environment.storage.root, client: client)
            environment.workspace = workspace
            environment.cloudAccount.beforeSignOut = { [weak workspace] in try await workspace?.prepareForSignOut() }
            environment.cloudAccount.signOutFailed = { [weak workspace] in
                (workspace?.maintenance.participant as? ReportEditorViewModel)?.setAutosavePaused(false)
            }
            onSession(workspace.session)
        } catch is CancellationError { }
        catch { self.error = error.localizedDescription }
    }
}
