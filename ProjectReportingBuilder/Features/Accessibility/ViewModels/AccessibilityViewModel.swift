import Observation

@MainActor
@Observable
final class AccessibilityViewModel {
    private(set) var report: AccessibilityReport?
    private(set) var isChecking = false
    private let checker: any AccessibilityChecking

    init(checker: any AccessibilityChecking = AccessibilityChecker()) { self.checker = checker }

    /// Replace the previous result only after an uncancelled manual check completes.
    func validate(model: AccessibilityValidationModel) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }
        let result = await checker.validate(model: model)
        guard !Task.isCancelled else { return }
        report = result
    }
}
