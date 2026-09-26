import SwiftUI
import AppKit

struct MetricRowView: View {
    let draft: EngineeringMetricDraft
    let canMoveUp: Bool
    let canMoveDown: Bool
    let edit: () -> Void
    let delete: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    let beginDrag: () -> NSItemProvider

    @State private var isHoveringHandle = false

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(isHoveringHandle ? Color.accentColor : Color.secondary)
                .onHover { hovering in
                    isHoveringHandle = hovering
                    if hovering { NSCursor.openHand.push() } else { NSCursor.pop() }
                }
                .padding(.vertical, AppSpacing.compact)
                .contentShape(Rectangle())
                .onDrag(beginDrag)
                .help("Drag to reorder metrics")
                .accessibilityLabel("Reorder metric " + draft.name)
                .accessibilityIdentifier("metricDragHandle." + draft.name)
            Button(action: edit) {
                rowContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit metric " + draft.name)
            Menu {
                Button("Edit Metric", action: edit)
                Button("Move Up", action: moveUp).disabled(!canMoveUp)
                Button("Move Down", action: moveDown).disabled(!canMoveDown)
                Divider()
                Button("Delete Metric", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Actions for metric " + draft.name)
            .accessibilityIdentifier("metricActions." + draft.name)
        }
        .padding(AppSpacing.cardInset)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

    }

    @ViewBuilder
    private var rowContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.inline) {
            Text(draft.name).font(.headline)
            if let metric = try? draft.makeMetric() {
                HStack {
                    Text(MetricPresentation.value(metric.currentValue, unit: metric.unit))
                    Spacer()
                    Text(MetricPresentation.target(metric)).foregroundStyle(.secondary)
                    if let severity = metric.severity { Text(severity.displayName).bold() }
                }
                Label(MetricPresentation.comparison(metric), systemImage: statusIcon(metric.targetStatus))
                    .font(.callout)
                    .foregroundStyle(metric.targetStatus == .missed ? Color.orange : Color.secondary)
            } else {
                Text("Invalid metric — edit to correct its values.").foregroundStyle(.red)
            }
        }
    }

    private func statusIcon(_ status: MetricTargetStatus) -> String {
        switch status {
        case .met: return "checkmark.circle"
        case .missed: return "exclamationmark.triangle"
        case .notSet: return "minus.circle"
        }
    }
}
