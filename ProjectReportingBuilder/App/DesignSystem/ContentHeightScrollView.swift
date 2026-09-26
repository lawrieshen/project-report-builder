import SwiftUI

/// Fit short content and scroll when the available height is insufficient.
struct ContentHeightScrollView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ViewThatFits(in: .vertical) {
            content().fixedSize(horizontal: false, vertical: true)
            ScrollView { content() }
        }
    }
}
