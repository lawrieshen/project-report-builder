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
            dragHandle
            editButton
            actionsMenu
        }
        .padding(AppSpacing.cardInset)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            if let metric = try? draft.makeMetric(), metric.targetStatus != .notSet {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(statusColor(metric.targetStatus), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
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
                    .foregroundStyle(statusColor(metric.targetStatus))
            } else {
                Text("Invalid metric — edit to correct its values.").foregroundStyle(.red)
            }
        }
    }

    private func statusColor(_ status: MetricTargetStatus) -> Color {
        switch status {
        case .met: return .green.mix(with: .secondary, by: 0.5)
        case .missed: return .orange.mix(with: .secondary, by: 0.5)
        case .notSet: return .secondary
        }
    }

    private func statusIcon(_ status: MetricTargetStatus) -> String {
        switch status {
        case .met: return "checkmark.circle"
        case .missed: return "exclamationmark.triangle"
        case .notSet: return "minus.circle"
        }
    }

    @ViewBuilder
    private var dragHandle: some View {
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
    }

    @ViewBuilder
    private var editButton: some View {
        Button(action: edit) {
            rowContent
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Edit metric " + draft.name)
    }

    @ViewBuilder
    private var actionsMenu: some View {
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
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Actions for metric " + draft.name)
        .accessibilityIdentifier("metricActions." + draft.name)
        .menuIndicator(.hidden)
    }
}

#Preview("Target States") {
    let met = EngineeringMetricDraft(metric: EngineeringMetric(
        id: UUID(), name: "Latency", currentValue: 80,
        target: MetricTarget(value: 100, comparison: .lessThan), unit: "ms", severity: nil))
    let missed = EngineeringMetricDraft(metric: EngineeringMetric(
        id: UUID(), name: "Build Duration", currentValue: 12,
        target: MetricTarget(value: 10, comparison: .lessThan), unit: "min", severity: nil))
    let noTarget = EngineeringMetricDraft(metric: EngineeringMetric(
        id: UUID(), name: "Test Count", currentValue: 250,
        target: nil, unit: nil, severity: nil))

    VStack(spacing: AppSpacing.field) {
        ForEach([met, missed, noTarget]) { draft in
            MetricRowView(draft: draft, canMoveUp: false, canMoveDown: false,
                          edit: {}, delete: {}, moveUp: {}, moveDown: {},
                          beginDrag: { NSItemProvider(object: draft.id.uuidString as NSString) })
        }
    }
    .padding(AppSpacing.pageInset)
    .frame(width: 520)
}
