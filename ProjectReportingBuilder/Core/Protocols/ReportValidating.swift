/// Evaluate a report snapshot without saving it or certifying accessibility compliance.
protocol ReportValidating {
    /// Check the supplied report snapshot.
    ///
    /// - Parameter model: Content and semantic information for validation.
    /// - Returns: Issues found by the enabled checks; an empty result is not certification.
    func validate(model: ReportValidationModel) async -> ReportValidationReport
}
