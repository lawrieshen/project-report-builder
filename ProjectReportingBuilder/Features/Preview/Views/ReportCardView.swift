import SwiftUI

enum PreviewImageState {
    case loaded(NSImage)
    case unavailable
}

/// Compose a read-only report from prepared content and decoded images.
struct ReportCardView: View {
    let model: ReportPreviewModel
    var images: [String: PreviewImageState] = [:]
    var now: Date = .now

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.section) {
            identity
            if model.ragStatus != nil || model.milestonePhase != nil || model.milestoneDeadline != nil {
                health
            }
            if !model.metrics.isEmpty {
                Divider()
                ReportPreviewMetricsView(metrics: model.metrics)
            }
            if !model.summaryMessage.isEmpty {
                Divider()
                summary
            }
            if !model.assets.isEmpty {
                Divider()
                ReportPreviewAssetsView(assets: model.assets, images: images)
            }
            if model.leadEPMName != nil || model.projectDRIName != nil {
                Divider()
                accountability
            }
        }
        .padding(ReportCardStyle.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor),
                    in: RoundedRectangle(cornerRadius: ReportCardStyle.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: ReportCardStyle.cornerRadius)
                .stroke(.primary.opacity(0.08))
        }
    }

    @ViewBuilder
    private var identity: some View {
        VStack(alignment: .leading, spacing: AppSpacing.inline) {
            Text(model.codeName.isEmpty ? "Untitled Project" : model.codeName)
                .font(ReportCardStyle.titleFont)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("previewCodeName")
            if !model.lineOfBusiness.isEmpty {
                Text(model.lineOfBusiness).font(.title3).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var health: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            if let status = model.ragStatus {
                Label(status.displayName, systemImage: "circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(status.color)
                    .padding(.horizontal, AppSpacing.field)
                    .padding(.vertical, AppSpacing.inline)
                    .background(status.color.opacity(0.12), in: Capsule())
            }
            if let phase = model.milestonePhase {
                Text(phase).font(.headline)
            }
            if let deadline = model.milestoneDeadline {
                Text(MilestoneCountdown.text(deadline: deadline, now: now)).font(.headline)
                Text(deadline, format: .dateTime.year().month(.abbreviated).day())
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var summary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            Text(summaryTitle).font(.headline).accessibilityAddTraits(.isHeader)
            Text(model.summaryMessage)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("previewSummary")
        }
    }

    private var summaryTitle: String {
        switch model.summaryType {
        case .update: return "Latest Update"
        case .blocker: return "Blocker"
        case .ask: return "Ask"
        }
    }

    @ViewBuilder
    private var accountability: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: ReportCardStyle.metricMinimumWidth), alignment: .leading)],
                  alignment: .leading, spacing: AppSpacing.field) {
            if let name = model.leadEPMName { person(name, role: "Lead EPM") }
            if let name = model.projectDRIName { person(name, role: "Project DRI") }
        }
    }

    private func person(_ name: String, role: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(role).font(.caption).foregroundStyle(.secondary)
            Text(name).font(.headline)
        }
    }
}
