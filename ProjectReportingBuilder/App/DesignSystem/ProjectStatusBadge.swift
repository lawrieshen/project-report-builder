import SwiftUI

/// Display project lifecycle status consistently across the app.
struct ProjectStatusBadge: View {
    let status: ProjectStatus

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, AppSpacing.inline)
            .padding(.vertical, AppSpacing.compact)
            .background(status.tint.opacity(0.2), in: Capsule())
            .fixedSize()
    }
}
