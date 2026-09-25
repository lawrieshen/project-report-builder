import Foundation
import CoreGraphics
import Observation

enum PreviewAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// Own display controls only; report content remains owned by the workspace.
@MainActor
@Observable
final class LivePreviewViewModel {
    private(set) var zoom = 1.0
    private(set) var isFitting = true
    var appearance: PreviewAppearance = .system

    func zoomIn(from displayedZoom: Double? = nil) {
        setZoom((displayedZoom ?? zoom) + 0.1)
    }

    func zoomOut(from displayedZoom: Double? = nil) {
        setZoom((displayedZoom ?? zoom) - 0.1)
    }

    func resetZoom() {
        isFitting = false
        zoom = 1
    }

    func fit() { isFitting = true }

    func displayedZoom(available: CGSize, content: CGSize) -> Double {
        guard isFitting else { return zoom }
        guard available.width > 0, available.height > 0,
              content.width > 0, content.height > 0 else { return 1 }
        return min(1, available.width / content.width, available.height / content.height)
    }

    private func setZoom(_ value: Double) {
        isFitting = false
        zoom = min(2, max(0.5, (value * 10).rounded() / 10))
    }
}
