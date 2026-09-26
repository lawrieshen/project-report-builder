import Observation

@MainActor
@Observable
final class ReportValidationViewModel {
    private(set) var report: ReportValidationReport?
    private(set) var isChecking = false
    private let checker: any ReportValidating

    init(checker: any ReportValidating = ReportValidator()) { self.checker = checker }

    /// Replace the previous result only after an uncancelled manual check completes.
    func validate(model: ReportValidationModel) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        let result = await checker.validate(model: model)
        guard !Task.isCancelled else { return }
        report = result
    }
}
