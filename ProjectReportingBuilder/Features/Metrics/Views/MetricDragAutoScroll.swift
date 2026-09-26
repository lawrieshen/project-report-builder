import SwiftUI
import AppKit

/// Scroll the enclosing editor while a metric is dragged near its visible edges.
struct MetricDragAutoScroll: NSViewRepresentable {
    let isDragging: Bool
    var onDragEnded: () -> Void

    func makeNSView(context: Context) -> AutoScrollView { AutoScrollView() }

    func updateNSView(_ view: AutoScrollView, context: Context) {
        view.onDragEnded = onDragEnded
        view.setDragging(isDragging)
    }

    static func dismantleNSView(_ view: AutoScrollView, coordinator: ()) {
        view.setDragging(false)
    }

    final class AutoScrollView: NSView {
        var onDragEnded: (() -> Void)?
        private var timer: Timer?
        private let edgeInset: CGFloat = 40
        private let scrollStep: CGFloat = 8

        func setDragging(_ active: Bool) {
            if !active {
                timer?.invalidate()
                timer = nil
            } else if timer == nil {
                let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
                    MainActor.assumeIsolated { self?.scrollIfNeeded() }
                }
                self.timer = timer
                RunLoop.main.add(timer, forMode: .common)
            }
        }

        private func scrollIfNeeded() {
            guard NSEvent.pressedMouseButtons & 1 != 0 else {
                setDragging(false)
                // Let the drop destination consume the drag before clearing cancelled sessions.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard NSEvent.pressedMouseButtons & 1 == 0 else { return }
                    self?.onDragEnded?()
                }
                return
            }
            guard let window, let scrollView = enclosingScrollView,
                  let document = scrollView.documentView else { return }
            let clip = scrollView.contentView
            let pointer = clip.convert(window.mouseLocationOutsideOfEventStream, from: nil)
            let bounds = clip.bounds
            guard bounds.contains(pointer) else { return }
            var delta: CGFloat = 0
            if pointer.y < bounds.minY + edgeInset { delta = -scrollStep }
            if pointer.y > bounds.maxY - edgeInset { delta = scrollStep }
            guard delta != 0 else { return }
            let maximumY = max(0, document.frame.height - bounds.height)
            let nextY = min(maximumY, max(0, bounds.origin.y + delta))
            clip.scroll(to: NSPoint(x: bounds.origin.x, y: nextY))
            scrollView.reflectScrolledClipView(clip)
        }
    }
}
