import SwiftUI
import UniformTypeIdentifiers

struct MetricsSectionView: View {
    @Bindable var viewModel: ReportEditorViewModel
    let editMetric: (EngineeringMetricDraft, Bool) -> Void
    @State private var draggedMetricID: UUID?
    @State private var insertionIndex: Int?
    @State private var rowHeights: [UUID: CGFloat] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var metrics: [EngineeringMetricDraft] { viewModel.draft?.metrics ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            sectionHeader
            if metrics.isEmpty {
                Text("No metrics yet").foregroundStyle(.secondary)
            }
            metricRows
        }
        .background(MetricDragAutoScroll(isDragging: draggedMetricID != nil) {
            draggedMetricID = nil
            insertionIndex = nil
        })

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
                moveDown: { viewModel.moveMetric(fromOffsets: IndexSet(integer: index), toOffset: index + 2) },
                beginDrag: {
                    draggedMetricID = metric.id
                    return NSItemProvider(object: metric.id.uuidString as NSString)
                })
                .onDrop(of: [UTType.text], delegate: MetricDropDelegate(
                    draggedID: $draggedMetricID, insertionIndex: $insertionIndex,
                    targetIndex: index, rowHeight: rowHeights[metric.id] ?? 100,
                    metrics: metrics, move: { source, destination in
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                            viewModel.moveMetric(fromOffsets: IndexSet(integer: source),
                                                 toOffset: destination)
                        }
                    }))
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    rowHeights[metric.id] = height
                }
                .overlay(alignment: .top) {
                    if insertionIndex == index {
                        Rectangle().fill(Color.accentColor).frame(height: 2)
                            .offset(y: -AppSpacing.field / 2).allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .bottom) {
                    if index == metrics.count - 1 && insertionIndex == metrics.count {
                        Rectangle().fill(Color.accentColor).frame(height: 2)
                            .offset(y: AppSpacing.field / 2).allowsHitTesting(false)
                    }
                }
        }
    }
}

private struct MetricDropDelegate: DropDelegate {
    @Binding var draggedID: UUID?
    @Binding var insertionIndex: Int?
    let targetIndex: Int
    let rowHeight: CGFloat
    let metrics: [EngineeringMetricDraft]
    let move: (Int, Int) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        metrics.contains { $0.id == draggedID }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        insertionIndex = targetIndex + (info.location.y >= rowHeight / 2 ? 1 : 0)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        insertionIndex = nil
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggedID = nil
            insertionIndex = nil
        }
        guard let source = metrics.firstIndex(where: { $0.id == draggedID }) else { return false }
        let destination = targetIndex + (info.location.y >= rowHeight / 2 ? 1 : 0)
        move(source, destination)
        return true
    }
}
