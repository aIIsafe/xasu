import SwiftUI

struct ConnectButton: View {

    let state: ConnectionState
    let action: () -> Void

    @State private var pulseScale: CGFloat = 1.0
    @State private var isPressed = false

    private var isActive: Bool { state == .connected }
    private var isConnecting: Bool { state == .connecting }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            ZStack {
                // Внешнее пульсирующее кольцо (только при подключении)
                if isConnecting {
                    Circle()
                        .strokeBorder(Color.xasuPurple.opacity(0.4), lineWidth: 2)
                        .frame(width: 150, height: 150)
                        .scaleEffect(pulseScale)
                        .opacity(2.5 - pulseScale * 1.5)
                        .animation(
                            .easeOut(duration: 1.2).repeatForever(autoreverses: false),
                            value: pulseScale
                        )
                }

                // Второе пульсирующее кольцо при connected
                if isActive {
                    Circle()
                        .strokeBorder(Color.xasuCyan.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 145, height: 145)
                        .scaleEffect(pulseScale)
                        .opacity(2 - pulseScale)
                        .animation(
                            .easeOut(duration: 2.0).repeatForever(autoreverses: false),
                            value: pulseScale
                        )
                }

                // Основная кнопка
                ZStack {
                    // Градиентный фон
                    Circle()
                        .fill(buttonGradient)
                        .frame(width: 120, height: 120)
                        .shadow(color: shadowColor, radius: isActive ? 30 : 12, x: 0, y: 6)

                    // Glass оверлей
                    Circle()
                        .fill(.ultraThinMaterial.opacity(0.4))
                        .frame(width: 120, height: 120)

                    // Обводка
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.35), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 120, height: 120)

                    // Иконка
                    buttonIcon
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .shadow(color: iconColor.opacity(0.6), radius: isActive ? 8 : 0)
                }
                .scaleEffect(isPressed ? 0.94 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
                .animation(.spring(response: 0.45, dampingFraction: 0.75), value: state)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
        .onAppear { startPulse() }
        .onChange(of: state) { _, _ in startPulse() }
    }

    // MARK: - Хелперы

    @ViewBuilder
    private var buttonIcon: some View {
        if isConnecting {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
        } else {
            Image(systemName: isActive ? "checkmark.shield.fill" : "shield.slash.fill")
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private var buttonGradient: LinearGradient {
        if isActive {
            return LinearGradient(
                colors: [Color.xasuCyan.opacity(0.9), Color.xasuPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isConnecting {
            return LinearGradient(
                colors: [Color.xasuPurple.opacity(0.8), Color.buttonInactive],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color.buttonInactive, Color.buttonInactive.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        isActive ? Color.xasuCyan.opacity(0.5) : Color.xasuPurple.opacity(0.25)
    }

    private var iconColor: Color {
        isActive ? .white : Color.xasuPurple.opacity(0.9)
    }

    private func startPulse() {
        pulseScale = 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            pulseScale = 1.45
        }
    }
}

#Preview {
    ZStack {
        Color.xasuBackground
        VStack(spacing: 40) {
            ConnectButton(state: .disconnected, action: {})
            ConnectButton(state: .connecting, action: {})
            ConnectButton(state: .connected, action: {})
        }
    }
}
