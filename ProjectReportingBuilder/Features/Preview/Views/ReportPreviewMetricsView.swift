import SwiftUI

struct ReportPreviewMetricsView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let style = ReportAccessibilityStyle.canonical
    private var palette: ReportPalette { style.palette(colorScheme) }
    let metrics: [ReportPreviewMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            ReportSectionHeading(section: .metrics)
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
            Text(item.name).font(.system(size: style.bodySize, weight: .semibold))
            if let metric = item.metric {
                Text(MetricPresentation.value(metric.currentValue, unit: metric.unit))
                    .font(ReportCardStyle.metricFont)
                Text(MetricPresentation.target(metric)).font(.system(size: style.captionSize)).foregroundStyle(palette.secondary.color)
                Label(ReportAccessibilityStyle.metricStatusLabel(metric.targetStatus), systemImage: statusIcon(metric.targetStatus))
                    .font(.system(size: style.captionSize))
                    .foregroundStyle(palette.primary.color)
                if let severity = metric.severity {
                    Text(severity.displayName).font(.system(size: style.captionSize, weight: .semibold))
                }
            } else {
                Label("Incomplete metric", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(palette.secondary.color)
                if let message = item.validationMessage { Text(message).font(.system(size: style.captionSize)) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.cardInset)
        .background(palette.tile.color, in: RoundedRectangle(cornerRadius: ReportCardStyle.tileRadius))
    }

    private func statusIcon(_ status: MetricTargetStatus) -> String {
        switch status {
        case .met: return "checkmark.circle"
        case .missed: return "exclamationmark.triangle"
        case .notSet: return "minus.circle"
        }
    }
}
