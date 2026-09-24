import SwiftUI

struct ProjectCardView: View {
    let project: ProjectReport
    let open: () -> Void
    let delete: () -> Void
    
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
        Button("Duplicate") {}.disabled(true)
        Button("Archive") {}.disabled(true)
        Divider()
        Button("Delete", role: .destructive, action: delete)
    }

    @ViewBuilder
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(project.codeName)
                .font(.headline)
                .lineLimit(2)
                .padding(.trailing, 28)
            Text(project.lineOfBusiness)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Label(project.status.displayName, systemImage: "circle.fill")
                .foregroundStyle(project.status.color)
            Text("Updated " + project.updatedAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(.quaternary)
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
        .padding()
        .accessibilityLabel("Actions for " + project.codeName)
    }
}
