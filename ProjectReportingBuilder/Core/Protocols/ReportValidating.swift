/// Check report data and accessibility inputs without changing the draft.
protocol ReportValidating {
    /// Collect issues for a snapshot of the report.
    /// - Parameter model: The data and presentation facts to check.
    /// - Returns: Detected issues; this result does not certify WCAG compliance.
    func validate(model: ReportValidationModel) async -> ReportValidationReport
}
