protocol AccessibilityChecking {
    func validate(model: AccessibilityValidationModel) async -> AccessibilityReport
}
