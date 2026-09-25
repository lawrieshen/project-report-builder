import Foundation

/// Check content and canonical design tokens; never certify an exported document.
struct AccessibilityChecker: AccessibilityChecking {
    var style = ReportAccessibilityStyle.canonical

    func validate(model: AccessibilityValidationModel) async -> AccessibilityReport {
        var issues: [AccessibilityIssue] = []
        func add(_ type: AccessibilityIssueType, _ severity: AccessibilitySeverity,
                 _ title: String, _ message: String, _ section: ReportSection) {
            issues.append(AccessibilityIssue(id: UUID(), type: type, severity: severity,
                                             title: title, message: message, section: section))
        }
        if model.codeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(.emptyLabel, .warning, "Missing project title", "Enter a project name to identify this report.", .identity)
        }
        for asset in model.assets where asset.altText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(.missingAltText, .error, "Missing alt text",
                "Image \"\(asset.fileName)\" needs a description of its purpose or content.", .supportingContent)
        }
        if let label = model.statusLabel, label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(.colorOnlyStatus, .error, "Status needs text", "Health must include a text label alongside its color.", .health)
        }
        for (index, name) in model.metricNames.enumerated() where name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            add(.emptyLabel, .warning, "Missing metric name", "Metric \(index + 1) needs a name to explain its value.", .metrics)
        }
        if model.metricStatusLabels.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            add(.colorOnlyStatus, .error, "Metric status needs text", "Metric results need textual meaning alongside their icons.", .metrics)
        }
        if model.roleLabels.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            add(.emptyLabel, .warning, "Missing role label", "The report layout must label each person's role.", .accountability)
        }
        for section in model.visibleSections {
            if !style.headingSections.contains(section) || style.titleLevel != 1 || style.sectionLevel != 2 {
                add(.missingHeading, .warning, "Missing heading hierarchy",
                    "The \(section.title) layout needs a semantic heading below the report title. This requires a layout update.", section)
            }
        }
        // These are product readability thresholds, not WCAG minimum font sizes.
        for (name, size, minimum) in [("Body", style.bodySize, 14.0), ("Caption", style.captionSize, 12.0),
                                      ("Heading", style.headingSize, 14.0), ("Title", style.titleSize, 14.0),
                                      ("Metric value", style.metricSize, 14.0)] {
            if !size.isFinite || size < minimum {
                add(.smallText, .warning, "Small \(name.lowercased()) text",
                    "\(name) text must be at least \(Int(minimum)) pt at actual size. This requires a layout update.", .identity)
            }
        }
        for palette in [style.light, style.dark] {
            for (name, foreground) in [("Primary", palette.primary), ("Secondary", palette.secondary)] {
                for (surface, background) in [("card", palette.background), ("tile", palette.tile)] {
                    let ratio = Self.contrast(foreground, background)
                    if !ratio.isFinite || ratio < 4.5 {
                        add(.lowContrast, .warning, "Low text contrast",
                            "\(palette.name) \(name.lowercased()) text on the \(surface) is below 4.5:1. This requires a layout color update.", .identity)
                    }
                }
            }
        }
        return AccessibilityReport(issues: issues)
    }

    /// Calculate sRGB text contrast using W3C relative luminance.
    /// https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
    static func contrast(_ first: ReportRGB, _ second: ReportRGB) -> Double {
        func luminance(_ color: ReportRGB) -> Double {
            func linear(_ value: Double) -> Double {
                guard value.isFinite, (0...1).contains(value) else { return .nan }
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
        }
        let a = luminance(first), b = luminance(second)
        guard a.isFinite, b.isFinite else { return .nan }
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}
