import SwiftUI

/// Confirm sign-out and retain the current screen if saving or credential removal fails.
struct CloudSignOutButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let account: CloudAccountStore
    var expandsOnHover = false
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @State private var confirmingSignOut = false
    @State private var signOutError: String?

    var body: some View {
        signOutControl
        .accessibilityLabel("Sign Out")
        .help("Sign Out")
        .accessibilityIdentifier("cloudSignOut")
        .disabled(account.isBusy)
        .confirmationDialog("Sign out? Unsynced edits will be kept as a recovery draft for this account.",
                            isPresented: $confirmingSignOut) {
            confirmationActions
        }
        .alert("Unable to Sign Out", isPresented: Binding(
            get: { signOutError != nil },
            set: { if !$0 { signOutError = nil } })) {
                Button("OK") { signOutError = nil }
            } message: {
                Text(signOutError ?? "")
            }
    }
    private var isExpanded: Bool { isHovered || isFocused }

    @ViewBuilder
    private var signOutControl: some View {
        if expandsOnHover {
            Button { confirmingSignOut = true } label: {
                HStack(spacing: 0) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 44, height: 44)
                    if isExpanded {
                        Text("Sign Out")
                            .font(.callout.weight(.medium))
                            .fixedSize()
                            .padding(.trailing, 16)
                            .transition(.opacity)
                    }
                }
                .background(.regularMaterial, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                }
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .onHover { isHovered = $0 }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isExpanded)
        } else {
            Button("Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                confirmingSignOut = true
            }
        }
    }

    @ViewBuilder
    private var confirmationActions: some View {
        Button("Sign Out") {
            Task {
                await account.signOut()
                if account.isSignedIn {
                    signOutError = account.message ?? "Unable to sign out. Please try again."
                }
            }
        }
        Button("Cancel", role: .cancel) {}
    }

}
