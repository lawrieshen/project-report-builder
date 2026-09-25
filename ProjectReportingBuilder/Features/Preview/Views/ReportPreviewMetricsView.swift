import SwiftUI

struct ReportPreviewMetricsView: View {
    let metrics: [ReportPreviewMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            Text("Engineering Metrics").font(.headline).accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: ReportCardStyle.metricMinimumWidth),
                                       spacing: AppSpacing.gridGap, alignment: .leading)],
                      alignment: .leading, spacing: AppSpacing.gridGap) {
                ForEach(metrics) { item in
                    metricTile(item)
                }
            }
        }
    }

    @ViewBuilder
    private func metricTile(_ item: ReportPreviewMetric) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.inline) {
            Text(item.name).font(.subheadline.weight(.semibold))
            if let metric = item.metric {
                Text(MetricPresentation.value(metric.currentValue, unit: metric.unit))
                    .font(ReportCardStyle.metricFont)
                Text(MetricPresentation.target(metric)).font(.caption).foregroundStyle(.secondary)
                Label(statusTitle(metric.targetStatus), systemImage: statusIcon(metric.targetStatus))
                    .font(.caption)
                    .foregroundStyle(metric.targetStatus == .missed ? Color.orange : Color.secondary)
                if let severity = metric.severity {
                    Text(severity.displayName).font(.caption.weight(.semibold))
                }
            } else {
                Label("Incomplete metric", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                if let message = item.validationMessage { Text(message).font(.caption) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardInset)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: ReportCardStyle.tileRadius))
    }

    private func statusTitle(_ status: MetricTargetStatus) -> String {
        switch status {
        case .met: return "Target Met"
        case .missed: return "Target Missed"
        case .notSet: return "Target Not Set"
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
