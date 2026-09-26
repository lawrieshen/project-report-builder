import SwiftUI

struct ProjectCardView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    let project: ProjectReport
    let open: () -> Void
    let delete: () -> Void
    
    var duplicate: () -> Void = {}

    var archive: () -> Void = {}

    var body: some View {
        Button(action: open) {
            cardContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open " + project.codeName)
        .overlay(alignment: .topTrailing) {
            actionsMenu
        }
        .contextMenu { actions }
    }
    
    @ViewBuilder
    private var actions: some View {
        Button("Open", action: open)
        Divider()
        Button("Duplicate", action: duplicate)
        Button("Archive", action: archive).disabled(project.status == .archived)
        Divider()
        Button("Delete", role: .destructive, action: delete)
    }
    
    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            Text(project.codeName)
                .font(.headline)
                .lineLimit(2)
                .padding(.trailing, 28)
            Text(project.lineOfBusiness)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            ProjectStatusBadge(status: project.status)
            if let health = project.card?.health.ragStatus {
                Label(health.displayName, systemImage: "circle.fill")
                    .foregroundStyle(health.color)
            } else {
                Text("Not assessed")
                    .foregroundStyle(.secondary)
            }
            Text("Updated " + project.updatedAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(AppSpacing.cardInset)
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background {
            let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
            if reduceTransparency {
                shape.fill(.background)
            } else {
                shape.fill(.clear)
                    .glassEffect(.regular, in: shape)
                shape.fill(
                    LinearGradient(
                        colors: [.white.opacity(colorScheme == .dark ? 0.1 : 0.35),
                                 .clear,
                                 .white.opacity(colorScheme == .dark ? 0.02 : 0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.primary.opacity(colorScheme == .dark ? 0.16 : 0.06),
                                 .primary.opacity(colorScheme == .dark ? 0.08 : 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
    }
    
    @ViewBuilder
    private var actionsMenu: some View {
        Menu {
            actions
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .padding(AppSpacing.cardInset)
        .accessibilityLabel("Actions for " + project.codeName)
    }
}
