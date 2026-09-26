import SwiftUI

struct MetricEditorView: View {
    let onDismiss: () -> Void
    @State private var draft: EngineeringMetricDraft
    @State private var saveError: String?
    let existingMetrics: [EngineeringMetricDraft]
    let onSave: (EngineeringMetricDraft) -> String?

    init(metric: EngineeringMetricDraft, existingMetrics: [EngineeringMetricDraft],
         onDismiss: @escaping () -> Void,
         onSave: @escaping (EngineeringMetricDraft) -> String?) {
        _draft = State(initialValue: metric)
        self.existingMetrics = existingMetrics
        self.onSave = onSave
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            Text("Metric Editor").font(.title2)
            ContentHeightScrollView {
                metricFields
            }
            if let message = draft.validationError(in: existingMetrics) ?? saveError {
                Text(message)
                    .font(.callout)
                    .floatingCardError(alignment: .center)
            }
            actionButtons
        }
        .floatingCard(width: 460)
    }

    @ViewBuilder
    private var metricFields: some View {
        Form {
            TextField("Metric Name", text: $draft.name)
                .accessibilityIdentifier("metricName")
            TextField("Current Value", text: $draft.currentValueText)
                .accessibilityIdentifier("metricCurrentValue")
            Text("Use a decimal point, for example 120.5. Grouping commas are not supported.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Unit", text: $draft.unit)
                .accessibilityIdentifier("metricUnit")
            Toggle("Set Target", isOn: $draft.hasTarget)
                .accessibilityIdentifier("metricHasTarget")
            if draft.hasTarget {
                Picker("Comparison", selection: $draft.comparison) {
                    ForEach(MetricComparison.allCases, id: \.self) { comparison in
                        Text(comparison.symbol).tag(comparison)
                    }
                }
                .accessibilityIdentifier("metricComparison")
                TextField("Target Value", text: $draft.targetValueText)
                    .accessibilityIdentifier("metricTargetValue")
            }
            Picker("Severity", selection: $draft.severity) {
                Text("None").tag(nil as MetricSeverity?)
                ForEach(MetricSeverity.allCases, id: \.self) { severity in
                    Text(severity.displayName).tag(Optional(severity))
                }
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Button("Cancel") { onDismiss() }
                .keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("cancelMetric")
            Spacer()
            Button("Save Metric") {
                saveError = onSave(draft)
                if saveError == nil { onDismiss() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(draft.validationError(in: existingMetrics) != nil)
            .accessibilityIdentifier("saveMetric")
        }
    }
}
