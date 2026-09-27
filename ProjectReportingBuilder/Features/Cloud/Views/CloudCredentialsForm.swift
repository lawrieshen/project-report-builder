import SwiftUI

/// Collect credentials only for the current sign-in attempt.
struct CloudCredentialsForm: View {
    let isBusy: Bool
    let needsNewPassword: Bool
    let signIn: (String, String) async -> Void
    let setNewPassword: (String) async -> Void
    let cancel: () -> Void

    @State private var email = ""
    @State private var password = ""
    @State private var confirmation = ""
    @State private var showsPassword = false
    @FocusState private var focusedField: Field?
    private enum Field { case email, password, confirmation }

    private var canSubmit: Bool {
        !isBusy && !password.isEmpty && (needsNewPassword
            ? password == confirmation
            : !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    var body: some View {
        VStack(alignment: .center, spacing: AppSpacing.field) {
            identityFields
            passwordField
            confirmationField
            formActions
        }
        .textFieldStyle(.plain)
        .controlSize(.large)
        .frame(width: 320)
        .disabled(isBusy)
        .onSubmit { submit() }
        .onChange(of: needsNewPassword) { _, _ in
            clearPassword()
            focusedField = .password
        }
        .onDisappear { clearPassword() }
    }

    @ViewBuilder
    private var identityFields: some View {
        if needsNewPassword {
            Text("Set a new password").font(.headline)
            Text("Use at least 12 characters with uppercase, lowercase, numbers, and symbols.")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            TextField("Email", text: $email)
                .textContentType(.username)
                .focused($focusedField, equals: .email)
                .accessibilityIdentifier("cloudEmail")
                .modifier(CredentialFieldStyle(isFocused: focusedField == .email))
        }
    }

    @ViewBuilder
    private var passwordField: some View {
        HStack {
            Group {
                if showsPassword { TextField("Password", text: $password) }
                else { SecureField("Password", text: $password) }
            }
            .textContentType(needsNewPassword ? .newPassword : .password)
            .focused($focusedField, equals: .password)
            .accessibilityIdentifier("cloudPassword")
            Button { showsPassword.toggle() } label: {
                Image(systemName: showsPassword ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showsPassword ? "Hide password" : "Show password")
        }
        .modifier(CredentialFieldStyle(isFocused: focusedField == .password))
    }

    @ViewBuilder
    private var confirmationField: some View {
        if needsNewPassword {
            SecureField("Confirm password", text: $confirmation)
                .textContentType(.newPassword)
                .focused($focusedField, equals: .confirmation)
                .accessibilityIdentifier("cloudConfirmPassword")
                .modifier(CredentialFieldStyle(isFocused: focusedField == .confirmation))
        }
    }

    @ViewBuilder
    private var formActions: some View {
        Button(action: submit) {
            Text(needsNewPassword ? "Update Password" : "Sign In")
                .frame(minHeight: 28)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canSubmit)
        .accessibilityIdentifier("cloudSignIn")
        if needsNewPassword {
            Button("Back to Sign In", action: cancel)
        }
    }

    private func submit() {
        guard canSubmit else { return }
        let submittedPassword = password
        clearPassword()
        Task {
            if needsNewPassword { await setNewPassword(submittedPassword) }
            else { await signIn(email, submittedPassword) }
        }
    }

    private func clearPassword() {
        password = ""
        confirmation = ""
        showsPassword = false
    }
}

/// Keep credential rows aligned, including the password visibility control.
private struct CredentialFieldStyle: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isFocused ? Color.accentColor : Color.primary.opacity(0.15),
                                  lineWidth: isFocused ? 2 : 1)
                    .allowsHitTesting(false)
            }
    }
}
