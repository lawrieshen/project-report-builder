import SwiftUI

struct CloudAccountView: View {
    @Bindable var account: CloudAccountStore
    @Bindable var transfers: CloudTransferStore

    var cloudPrimary = false
    @State private var confirmingSignOut = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text("Cloud Account").font(.title2.bold())
            Text(account.isSignedIn ? "Signed in" : "Not signed in")
            Text(cloudPrimary ? "Reports are saved to your cloud account. Unsynced drafts remain on this Mac for recovery." : "Sign in with your assigned test account. Local reports remain available without signing in.")
                .foregroundStyle(.secondary)
            HStack {
                if account.isSignedIn {
                    Button("Sign Out") { confirmingSignOut = true }
                } else {
                    Button("Sign In") { Task { await account.signIn() } }
                }
                if account.isBusy { ProgressView().controlSize(.small) }
            }
            .disabled(account.isBusy || transfers.isBusy)
            if let message = account.message { Text(message).foregroundStyle(.secondary) }
            if account.isSignedIn {
                if cloudPrimary {
                    CloudMigrationView(store: transfers).disabled(account.isBusy)
                } else {
                    CloudTransferView(store: transfers).disabled(account.isBusy)
                }
            }
        }
        .confirmationDialog("Sign out? Unsynced edits will be kept as a recovery draft for this account.", isPresented: $confirmingSignOut) {
            Button("Sign Out") { Task { await account.signOut() } }
            Button("Cancel", role: .cancel) { }
        }
        .task { await account.restore() }
        .onChange(of: account.isSignedIn) { _, signedIn in
            if !signedIn { transfers.clear() }
        }
    }
}
