import SwiftUI

/// Generate a self-contained semantic document without scripts or external asset URLs.
enum ReportHTMLRenderer {
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    static func render(model: ReportPreviewModel, images: [String: NSImage], options: ExportOptions) throws -> Data {
        let style = ReportAccessibilityStyle.canonical
        let palette = style.palette(options.appearance == .dark ? .dark : .light)
        let title = model.codeName.isEmpty ? "Untitled Project" : model.codeName
        var body = "<header><h1>\(escape(title))</h1>"
        if !model.lineOfBusiness.isEmpty { body += "<p class=secondary>\(escape(model.lineOfBusiness))</p>" }
        if let size = model.projectSize {
            body += "<p class=secondary>Project Size: \(escape(size.displayName))</p>"
        }
        body += "</header>"
        if model.ragStatus != nil || model.milestonePhase != nil || model.milestoneDeadline != nil {
            var health = ""
            if let status = model.ragStatus {
                let color: String
                switch status {
                case .green: color = "#248a3d"
                case .amber: color = "#ff9500"
                case .red: color = "#ff3b30"
                }
                health += "<p class=status><span aria-hidden=true style=\"color:\(color)\">●</span> \(escape(status.displayName))</p>"
            }
            if let phase = model.milestonePhase { health += "<p><strong>\(escape(phase))</strong></p>" }
            if let deadline = model.milestoneDeadline {
                health += "<p><strong>\(escape(MilestoneCountdown.text(deadline: deadline, now: options.date)))</strong></p>"
                health += "<p class=secondary>\(escape(deadline.formatted(.dateTime.year().month(.abbreviated).day())))</p>"
            }
            body += section(.health, content: health)
        }
        if !model.metrics.isEmpty {
            var tiles = "<div class=metrics>"
            for item in model.metrics {
                tiles += "<div class=tile><h3>\(escape(item.name))</h3>"
                if let metric = item.metric {
                    tiles += "<p class=value>\(escape(MetricPresentation.value(metric.currentValue, unit: metric.unit)))</p>"
                    tiles += "<p class=caption>\(escape(MetricPresentation.target(metric)))</p>"
                    tiles += "<p class=caption>\(escape(ReportAccessibilityStyle.metricStatusLabel(metric.targetStatus)))</p>"
                    if let severity = metric.severity { tiles += "<p class=caption>\(escape(severity.displayName))</p>" }
                } else {
                    tiles += "<p>Incomplete metric</p>"
                    if let message = item.validationMessage { tiles += "<p class=caption>\(escape(message))</p>" }
                }
                tiles += "</div>"
            }
            body += section(.metrics, content: tiles + "</div>")
        }
        if !model.summaryMessage.isEmpty {
            body += section(.summary, title: model.summaryHeading,
                            content: "<p class=summary>\(escape(model.summaryMessage))</p>")
        }
        if !model.assets.isEmpty {
            var assets = "<div class=assets>"
            for asset in model.assets {
                guard let image = images[asset.localReference],
                      let pixels = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
                      let png = NSBitmapImageRep(cgImage: pixels).representation(using: .png, properties: [:]) else {
                    throw ExportError.imageUnavailable(asset.fileName)
                }
                assets += "<img src=\"data:image/png;base64,\(png.base64EncodedString())\" alt=\"\(escape(asset.altText))\">"
            }
            body += section(.supportingContent, content: assets + "</div>")
        }
        if model.leadEPMName != nil || model.projectDRIName != nil {
            var people = "<dl class=people>"
            if let name = model.leadEPMName { people += person(name, role: style.leadRole) }
            if let name = model.projectDRIName { people += person(name, role: style.driRole) }
            body += section(.accountability, content: people + "</dl>")
        }
        let html = """
        <!doctype html>
        <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title><style>
        * { box-sizing: border-box; }
        body { margin: 0; padding: 24px; font-family: -apple-system, BlinkMacSystemFont, sans-serif;
          font-size: \(style.bodySize)px; background: \(css(palette.background)); color: \(css(palette.primary)); }
        article { max-width: \(ReportCardStyle.standardWidth)px; margin: auto; padding: \(ReportCardStyle.contentInset)px;
          border-radius: \(ReportCardStyle.cornerRadius)px; overflow-wrap: anywhere; }
        h1 { margin: 0; font-size: \(style.titleSize)px; } h2 { font-size: \(style.headingSize)px; }
        h3 { font-size: \(style.bodySize)px; margin: 0; } p { margin: 12px 0; }
        section { margin-top: 24px; padding-top: 12px; border-top: 1px solid \(css(palette.secondary)); }
        .secondary, .caption, dt { color: \(css(palette.secondary)); }
        .caption, dt { font-size: \(style.captionSize)px; }
        .metrics, .assets, .people { display: grid; gap: 16px; grid-template-columns: repeat(auto-fit, minmax(min(100%, 180px), 1fr)); }
        .assets { grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); }
        .tile, .status { background: \(css(palette.tile)); border-radius: \(ReportCardStyle.tileRadius)px; padding: 16px; }
        .status { display: inline-block; border-radius: 999px; padding: 8px 12px; }
        .value { font-size: \(style.metricSize)px; font-weight: 600; }
        .summary { white-space: pre-wrap; } dd { margin: 4px 0 0; font-weight: 600; }
        img { width: 100%; height: \(ReportCardStyle.imageHeight)px; object-fit: contain; background: \(css(palette.tile)); border-radius: 12px; }
        </style></head><body><article>\(body)</article></body></html>
        """
        let data = Data(html.utf8)
        guard data.count <= 64 * 1_048_576 else { throw ExportError.reportTooLarge }
        return data
    }

    private static func section(_ section: ReportSection, title: String? = nil, content: String) -> String {
        "<section aria-labelledby=\"\(section.rawValue)\"><h2 id=\"\(section.rawValue)\">\(escape(title ?? section.title))</h2>\(content)</section>"
    }

    private static func person(_ name: String, role: String) -> String {
        "<div><dt>\(escape(role))</dt><dd>\(escape(name))</dd></div>"
    }

    private static func css(_ color: ReportRGB) -> String {
        "rgb(\(Int((color.red * 255).rounded())),\(Int((color.green * 255).rounded())),\(Int((color.blue * 255).rounded())))"
    }
}
