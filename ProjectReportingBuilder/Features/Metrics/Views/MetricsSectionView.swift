import SwiftUI

struct MetricsSectionView: View {
    @Bindable var viewModel: ReportEditorViewModel
    let editMetric: (EngineeringMetricDraft, Bool) -> Void

    private var metrics: [EngineeringMetricDraft] { viewModel.draft?.metrics ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            sectionHeader
            if metrics.isEmpty {
                Text("No metrics yet").foregroundStyle(.secondary)
            }
            metricRows
        }

    }

    @ViewBuilder
    private var sectionHeader: some View {
        HStack {
            Text("Engineering Metrics").font(.title3.bold())
            Spacer()
            Button {
                editMetric(EngineeringMetricDraft(), true)
            } label: {
                Label("Add Metric", systemImage: "plus")
            }
            .accessibilityIdentifier("addMetric")
        }
    }

    @ViewBuilder
    private var metricRows: some View {
        ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
            MetricRowView(draft: metric, canMoveUp: index > 0, canMoveDown: index < metrics.count - 1,
                edit: {
                    editMetric(metric, false)
                },
                delete: { viewModel.deleteMetric(id: metric.id) },
                moveUp: { viewModel.moveMetric(fromOffsets: IndexSet(integer: index), toOffset: index - 1) },
                moveDown: { viewModel.moveMetric(fromOffsets: IndexSet(integer: index), toOffset: index + 2) })
        }
    }
}
