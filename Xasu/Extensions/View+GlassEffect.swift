import SwiftUI

// MARK: - Liquid Glass модификаторы

struct LiquidGlassModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tintColor: Color
    var tintOpacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(tintColor.opacity(tintOpacity))
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct CircleGlassModifier: ViewModifier {
    var tintColor: Color
    var tintOpacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(tintColor.opacity(tintOpacity))
                    Circle().strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
                }
            }
            .clipShape(Circle())
    }
}

extension View {
    func liquidGlass(
        cornerRadius: CGFloat = 16,
        tintColor: Color = .white,
        tintOpacity: Double = 0.05
    ) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius, tintColor: tintColor, tintOpacity: tintOpacity))
    }

    func circleGlass(
        tintColor: Color = .white,
        tintOpacity: Double = 0.05
    ) -> some View {
        modifier(CircleGlassModifier(tintColor: tintColor, tintOpacity: tintOpacity))
    }
}
