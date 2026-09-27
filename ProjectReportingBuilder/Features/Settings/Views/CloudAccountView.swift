import SwiftUI

struct CloudAccountView: View {
    @Bindable var account: CloudAccountStore
    @Bindable var transfers: CloudTransferStore

    var cloudPrimary = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text("Cloud Account").font(.title2.bold())
            Text(account.isSignedIn ? "Signed in" : "Not signed in")
            Text(cloudPrimary ? "Reports are saved to your cloud account. Unsynced drafts remain on this Mac for recovery." : "Sign in with your assigned test account. Local reports remain available without signing in.")
                .foregroundStyle(.secondary)
            HStack {
                if account.isSignedIn {
                    CloudSignOutButton(account: account)
                } else {
                    CloudCredentialsForm(isBusy: account.isBusy,
                        needsNewPassword: account.passwordChallenge != nil,
                        signIn: { await account.signIn(email: $0, password: $1) },
                        setNewPassword: { await account.setNewPassword($0) },
                        cancel: { account.cancelPasswordChallenge() })
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
        .task { await account.restore() }
        .onChange(of: account.isSignedIn) { _, signedIn in
            if !signedIn { transfers.clear() }
        }
    }
}
