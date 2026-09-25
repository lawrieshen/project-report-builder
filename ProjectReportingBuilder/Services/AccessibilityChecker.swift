import Foundation

/// Check content and canonical design tokens; never certify an exported document.
struct AccessibilityChecker: AccessibilityChecking {

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
        return AccessibilityReport(issues: issues)
    }
}
