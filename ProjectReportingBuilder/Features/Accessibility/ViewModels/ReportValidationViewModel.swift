import Observation

@MainActor
@Observable
final class ReportValidationViewModel {
    private(set) var report: ReportValidationReport?
    private(set) var isChecking = false
    private var generation = 0
    private let checker: any ReportValidating

    init(checker: any ReportValidating = ReportValidator()) { self.checker = checker }

    /// Publish only the newest validation request, including automatic checks while editing.
    func validate(model: ReportValidationModel) async {
        generation += 1
        let request = generation
        report = nil
        isChecking = true
        defer { if generation == request { isChecking = false } }
        let result = await checker.validate(model: model)
        guard generation == request, !Task.isCancelled else { return }
        report = result
    }
}
