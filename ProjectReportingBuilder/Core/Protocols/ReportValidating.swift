protocol ReportValidating {
    func validate(model: ReportValidationModel) async -> ReportValidationReport
}
