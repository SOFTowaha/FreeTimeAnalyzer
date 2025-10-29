import SwiftUI

// Reusable glassy button style
struct GlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 10
    var paddingH: CGFloat = 12
    var paddingV: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, paddingH)
            .padding(.vertical, paddingV)
            .background(
                ZStack {
                    // base frosted layer
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    // subtle gloss
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(configuration.isPressed ? 0.08 : 0.04), lineWidth: 1)
                }
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.98 : 1)
    }
}

// Modifier for glassy control containers (pickers, steppers)
struct GlassControlModifier: ViewModifier {
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.03), lineWidth: 1)
            )
    }
}

extension View {
    func glassControl(cornerRadius: CGFloat = 10) -> some View {
        modifier(GlassControlModifier(cornerRadius: cornerRadius))
    }
}
