import SwiftUI

/// Display sign-in states independently of authentication and network requests.
struct CloudSignInView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false
    private let titleWords = ["Project", "Report", "Builder"]

    let isSignedIn: Bool
    let isLoading: Bool
    let isBusy: Bool
    let message: String?
    let signIn: () -> Void
    let retry: () -> Void
    let signOut: () -> Void

    private var shouldAnimateEntrance: Bool {
        !isSignedIn && !isLoading && !isBusy && message == nil && !reduceMotion
    }

    private var isContentVisible: Bool {
        !shouldAnimateEntrance || hasAppeared
    }

    var body: some View {
        VStack(spacing: AppSpacing.section) {
            Image(systemName: "apple.logo")
                .font(.system(size: 40))
            HStack(spacing: 8) {
                ForEach(titleWords.indices, id: \.self) { index in
                    Text(titleWords[index])
                        .opacity(isContentVisible ? 1 : 0)
                        .offset(y: isContentVisible ? 0 : 8)
                        .animation(
                            shouldAnimateEntrance ? .easeOut(duration: 0.5)
                                .delay(Double(index) * 0.16) : nil,
                            value: hasAppeared)
                }
            }
            .font(.largeTitle.bold())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(titleWords.joined(separator: " "))
            .accessibilityAddTraits(.isHeader)
            Text("Sign in to open your cloud reports.").foregroundStyle(.secondary)
            if isLoading || isBusy { ProgressView() }
            if let message {
                Text(message).foregroundStyle(.secondary)
            }
            if isSignedIn {
                Button("Retry", action: retry).disabled(isLoading)
                Button("Sign Out", action: signOut)
            } else {
                Button("Sign In", action: signIn)
                    .disabled(isBusy)
                    .accessibilityIdentifier("cloudSignIn")
            }
        }
        .opacity(isContentVisible ? 1 : 0)
        .offset(y: isContentVisible ? 0 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .disabled(isBusy)
        .transaction { transaction in
            if !shouldAnimateEntrance {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
        .task(id: shouldAnimateEntrance) {
            guard shouldAnimateEntrance, !hasAppeared else { return }
            do {
                try await Task.sleep(for: .milliseconds(150))
            } catch {
                // Leaving sign-in cancels the pending entrance animation.
                return
            }
            withAnimation(.easeOut(duration: 0.6)) {
                hasAppeared = true
            }
        }
    }
}

#Preview("Sign In") {
    CloudSignInView(isSignedIn: false, isLoading: false, isBusy: false, message: nil,
                    signIn: {}, retry: {}, signOut: {})
        .frame(width: 760, height: 400)
}

#Preview("Loading") {
    CloudSignInView(isSignedIn: true, isLoading: true, isBusy: false, message: nil,
                    signIn: {}, retry: {}, signOut: {})
        .frame(width: 760, height: 400)
}

#Preview("Connection Error") {
    CloudSignInView(isSignedIn: true, isLoading: false, isBusy: false,
                    message: "Unable to connect. Please try again.", signIn: {}, retry: {}, signOut: {})
        .frame(width: 760, height: 400)
}
