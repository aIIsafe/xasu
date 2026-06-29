import SwiftUI

struct ConnectButton: View {

    let state: ConnectionState
    let action: () -> Void

    @State private var pulseOpacity: Double = 0
    @State private var pulseScale: CGFloat = 0.85
    @State private var isPressed = false

    private var isActive:     Bool { state == .connected }
    private var isConnecting: Bool { state == .connecting }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            ZStack {
                // Внешнее пульсирующее кольцо
                if isActive || isConnecting {
                    Circle()
                        .strokeBorder(
                            isActive
                                ? Color.xasuCyan.opacity(0.35)
                                : Color.xasuPurple.opacity(0.4),
                            lineWidth: 1.5
                        )
                        .frame(width: 154, height: 154)
                        .scaleEffect(pulseScale)
                        .opacity(pulseOpacity)
                }

                // Основной круг
                ZStack {
                    // Фон-градиент
                    Circle()
                        .fill(fillGradient)
                        .frame(width: 120, height: 120)

                    // Material glass overlay
                    Circle()
                        .fill(.ultraThinMaterial.opacity(isActive ? 0.25 : 0.4))
                        .frame(width: 120, height: 120)

                    // Обводка
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                        .frame(width: 120, height: 120)

                    // Иконка
                    if isConnecting {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.3)
                    } else {
                        Image(systemName: "power")
                            .font(.system(size: 34, weight: .light))
                            .foregroundStyle(iconColor)
                            .shadow(color: iconColor.opacity(isActive ? 0.7 : 0.2), radius: isActive ? 10 : 0)
                    }
                }
                .shadow(color: shadowColor, radius: isActive ? 28 : 10, x: 0, y: 6)
                .scaleEffect(isPressed ? 0.93 : 1.0)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: state)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
        .onAppear { animatePulse() }
        .onChange(of: state) { _, _ in animatePulse() }
    }

    // MARK: - Стили

    private var fillGradient: LinearGradient {
        if isActive {
            return LinearGradient(
                colors: [Color.xasuCyan.opacity(0.75), Color.xasuPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isConnecting {
            return LinearGradient(
                colors: [Color.xasuPurple.opacity(0.7), Color.buttonInactive],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 0.14, green: 0.12, blue: 0.22), Color(red: 0.10, green: 0.09, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var shadowColor: Color {
        isActive ? Color.xasuCyan.opacity(0.45) : Color.xasuPurple.opacity(0.2)
    }

    private var iconColor: Color {
        isActive ? .white : Color.xasuPurple.opacity(0.85)
    }

    private func animatePulse() {
        guard isActive || isConnecting else {
            pulseOpacity = 0; pulseScale = 0.85
            return
        }
        pulseScale = 0.85; pulseOpacity = 0.9
        withAnimation(
            .easeOut(duration: isConnecting ? 1.1 : 1.6).repeatForever(autoreverses: false)
        ) {
            pulseScale = 1.3; pulseOpacity = 0
        }
    }
}

#Preview {
    ZStack {
        Color.xasuBackground.ignoresSafeArea()
        VStack(spacing: 40) {
            ConnectButton(state: .disconnected, action: {})
            ConnectButton(state: .connecting,   action: {})
            ConnectButton(state: .connected,    action: {})
        }
    }
}
