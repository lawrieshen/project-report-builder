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
                    settings: environment.settings, session: workspace.session, maintenance: workspace.maintenance,
                    cloudAccount: environment.cloudAccount, aiComposerEnabled: true)
                    .id(environment.cloudAccount.sessionID)
            } else {
                CloudSignInView(
                    isSignedIn: environment.cloudAccount.isSignedIn,
                    isLoading: loading,
                    isBusy: environment.cloudAccount.isBusy,
                    message: error ?? environment.cloudAccount.message,
                    signIn: { email, password in await environment.cloudAccount.signIn(email: email, password: password) },
                    needsNewPassword: environment.cloudAccount.passwordChallenge != nil,
                    setNewPassword: { await environment.cloudAccount.setNewPassword($0) },
                    cancelPasswordChallenge: { environment.cloudAccount.cancelPasswordChallenge() },
                    retry: { Task { await openWorkspace() } },
                    signOut: { Task { await environment.cloudAccount.signOut() } })
            }
        }
        .disabled(environment.cloudAccount.isBusy)
        .frame(minWidth: 760, minHeight: 560)
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
