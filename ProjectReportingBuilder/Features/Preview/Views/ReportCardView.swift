import SwiftUI

enum PreviewImageState {
    case loaded(NSImage)
    case unavailable
}

/// Compose a read-only report from prepared content and decoded images.
struct ReportCardView: View {
    @Environment(\.colorScheme) private var colorScheme
    private let style = ReportAccessibilityStyle.canonical
    private var palette: ReportPalette { style.palette(colorScheme) }
    let model: ReportPreviewModel
    var images: [String: PreviewImageState] = [:]
    var now: Date = .now
    var drawsBackground = true

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
        .font(.system(size: style.bodySize))
        .foregroundStyle(palette.primary.color)
        .padding(ReportCardStyle.contentInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(drawsBackground ? palette.background.color : Color.clear,
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
                .accessibilityAddTraits(style.headingSections.contains(.identity) ? .isHeader : [])
                .accessibilityHeading(style.titleLevel == 1 ? .h1 : .unspecified)
                .accessibilityIdentifier("previewCodeName")
            if !model.lineOfBusiness.isEmpty {
                Text(model.lineOfBusiness).font(.system(size: style.headingSize)).foregroundStyle(palette.secondary.color)
            }
        }
    }

    @ViewBuilder
    private var health: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            ReportSectionHeading(section: .health)
            if let status = model.ragStatus {
                Label { Text(status.displayName) } icon: {
                    Image(systemName: "circle.fill").foregroundStyle(status.color)
                }
                    .font(.system(size: style.bodySize, weight: .semibold))
                    .padding(.horizontal, AppSpacing.field)
                    .padding(.vertical, AppSpacing.inline)
                    .background(palette.tile.color, in: Capsule())
            }
            if let phase = model.milestonePhase {
                Text(phase).font(.system(size: style.headingSize, weight: .semibold))
            }
            if let deadline = model.milestoneDeadline {
                Text(MilestoneCountdown.text(deadline: deadline, now: now)).font(.system(size: style.headingSize, weight: .semibold))
                Text(deadline, format: .dateTime.year().month(.abbreviated).day())
                    .font(.system(size: style.bodySize)).foregroundStyle(palette.secondary.color)
            }
        }
    }

    @ViewBuilder
    private var summary: some View {
        VStack(alignment: .leading, spacing: AppSpacing.field) {
            ReportSectionHeading(section: .summary, title: model.summaryHeading)
            Text(model.summaryMessage)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("previewSummary")
        }
    }

    @ViewBuilder
    private var accountability: some View {
        ReportSectionHeading(section: .accountability)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: ReportCardStyle.metricMinimumWidth), alignment: .leading)],
                  alignment: .leading, spacing: AppSpacing.field) {
            if let name = model.leadEPMName { person(name, role: style.leadRole) }
            if let name = model.projectDRIName { person(name, role: style.driRole) }
        }
    }

    private func person(_ name: String, role: String) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.compact) {
            Text(role).font(.system(size: style.captionSize)).foregroundStyle(palette.secondary.color)
            Text(name).font(.system(size: style.headingSize, weight: .semibold))
        }
    }
}
