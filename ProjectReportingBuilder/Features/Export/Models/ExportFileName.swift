import Foundation

/// Produce a single filename component, never a relative or absolute path.
enum ExportFileName {
    static func baseName(_ projectName: String) -> String {
        let allowed = CharacterSet.letters.union(.decimalDigits)
        var result = ""
        for scalar in projectName.precomposedStringWithCanonicalMapping.unicodeScalars {
            if allowed.contains(scalar) || scalar == "_" {
                result.unicodeScalars.append(scalar)
            } else if !result.isEmpty && !result.hasSuffix("-") {
                result.append("-")
            }
            // Bound UTF-8 bytes so multibyte project names fit common filesystem limits.
            if result.utf8.count > 160 {
                result.removeLast()
                break
            }
        }
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "Report" : result
    }

    static func fileName(_ projectName: String, format: ExportFormat) -> String {
        baseName(projectName) + "." + format.rawValue
    }
}
