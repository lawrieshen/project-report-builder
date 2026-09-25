import SwiftUI

/// Style and size a floating card using New Project as the default.
struct FloatingCardSurface: ViewModifier {
    var width: CGFloat = 420
    var maxHeight: CGFloat? = nil
    var padding: CGFloat = AppSpacing.dialogInset


    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(width: width)
            .frame(maxHeight: maxHeight, alignment: .top)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.2), radius: 24, x: 0, y: 8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.primary.opacity(0.08))
            }
    }
}


extension View {
    /// Use `maxHeight: .infinity` to fill the available vertical space.
    func floatingCard(
        width: CGFloat = 420,
        maxHeight: CGFloat? = nil,
        padding: CGFloat = AppSpacing.dialogInset
    ) -> some View {
        modifier(FloatingCardSurface(width: width, maxHeight: maxHeight, padding: padding))
    }

    /// Align error text independently from the card's other content.
    func floatingCardError(alignment: TextAlignment = .leading) -> some View {
        modifier(FloatingCardError(alignment: alignment))
    }
}

private struct FloatingCardError: ViewModifier {
    let alignment: TextAlignment

    private var frameAlignment: Alignment {
        switch alignment {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.red)
            .multilineTextAlignment(alignment)
            .frame(maxWidth: .infinity, alignment: frameAlignment)
    }
}
