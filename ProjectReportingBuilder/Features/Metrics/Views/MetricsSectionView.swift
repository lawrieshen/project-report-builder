import SwiftUI

struct MetricsSectionView: View {
    @Bindable var viewModel: ReportEditorViewModel
    @State private var editingMetric: EngineeringMetricDraft?
    @State private var isAdding = false

    private var metrics: [EngineeringMetricDraft] { viewModel.draft?.metrics ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader
            if metrics.isEmpty {
                Text("No metrics yet").foregroundStyle(.secondary)
            }
            metricRows
        }
        .sheet(item: $editingMetric) { metric in
            MetricEditorView(metric: metric, existingMetrics: metrics) { confirmed in
                if isAdding { return viewModel.addMetric(confirmed) }
                return viewModel.updateMetric(confirmed)
            }
        }
    }

    @ViewBuilder
    private var sectionHeader: some View {
        HStack {
            Text("Engineering Metrics").font(.title3.bold())
            Spacer()
            Button {
                isAdding = true
                editingMetric = EngineeringMetricDraft()
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
                    isAdding = false
                    editingMetric = metric
                },
                delete: { viewModel.deleteMetric(id: metric.id) },
                moveUp: { viewModel.moveMetric(fromOffsets: IndexSet(integer: index), toOffset: index - 1) },
                moveDown: { viewModel.moveMetric(fromOffsets: IndexSet(integer: index), toOffset: index + 2) })
        }
    }
}
