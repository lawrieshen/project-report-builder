import SwiftUI

struct CloudAccountView: View {
    @Bindable var account: CloudAccountStore
    @Bindable var transfers: CloudTransferStore

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text("Cloud Account").font(.title2.bold())
            Text(account.isSignedIn ? "Signed in" : "Not signed in")
            Text("Sign in with your assigned test account. Local reports remain available without signing in.")
                .foregroundStyle(.secondary)
            HStack {
                if account.isSignedIn {
                    Button("Sign Out") { Task { await account.signOut() } }
                } else {
                    Button("Sign In") { Task { await account.signIn() } }
                }
                if account.isBusy { ProgressView().controlSize(.small) }
            }
            .disabled(account.isBusy || transfers.isBusy)
            if let message = account.message { Text(message).foregroundStyle(.secondary) }
            if account.isSignedIn {
                CloudTransferView(store: transfers).disabled(account.isBusy)
            }
        }
        .task { await account.restore() }
        .onChange(of: account.isSignedIn) { _, signedIn in
            if !signedIn { transfers.clear() }
        }
    }
}
