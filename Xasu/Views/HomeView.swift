import SwiftUI

struct HomeView: View {

    @State private var settingsVM = SettingsViewModel()
    @State private var connectionVM: ConnectionViewModel

    @State private var showSettings = false
    @State private var showLogs     = false
    @State private var appeared     = false

    init() {
        let s = SettingsViewModel()
        _settingsVM  = State(initialValue: s)
        _connectionVM = State(initialValue: ConnectionViewModel(settingsVM: s))
    }

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 0) {

                // ── Шапка ─────────────────────────────────────────────
                topBar
                    .padding(.top, 56)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : -12)

                Spacer()

                // ── Кнопка подключения ────────────────────────────────
                ConnectButton(
                    state: connectionVM.connectionState,
                    action: { connectionVM.toggleConnection() }
                )
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.85)

                // ── Статус ────────────────────────────────────────────
                statusBlock
                    .padding(.top, 28)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer()

                // ── Нижние кнопки ─────────────────────────────────────
                bottomBar
                    .padding(.bottom, 48)
                    .opacity(appeared ? 1 : 0)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .alert("Connection Error", isPresented: Binding(
            get: { connectionVM.errorMessage != nil },
            set: { if !$0 { connectionVM.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { connectionVM.errorMessage = nil }
        } message: {
            Text(connectionVM.errorMessage ?? "")
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: settingsVM)
        }
        .sheet(isPresented: $showLogs) {
            LogsView()
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.82).delay(0.1)) {
                appeared = true
            }
        }
        .onChange(of: VPNManager.shared.status) { _, _ in
            connectionVM.onVPNStatusChange()
        }
    }

    // MARK: - Компоненты

    private var topBar: some View {
        HStack {
            // Лого
            VStack(alignment: .leading, spacing: 3) {
                Text("XASU")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.xasuCyan, Color.xasuPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.xasuPurple.opacity(0.4), radius: 8)

                Text("DPI BYPASS")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.textTertiary)
                    .tracking(3)
            }

            Spacer()

            // Кнопка логов
            Button(action: { showLogs = true }) {
                Image(systemName: "doc.text")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 36, height: 36)
                    .liquidGlass(cornerRadius: 12, tintColor: .white, tintOpacity: 0.04)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                if !AppLogger.shared.entries.isEmpty {
                    Circle()
                        .fill(Color.xasuCyan)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var statusBlock: some View {
        VStack(spacing: 8) {
            // Статус текст
            Text(connectionVM.connectionState.displayTitle)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35), value: connectionVM.connectionState)

            // Бейдж режима (VPN / SOCKS)
            if connectionVM.connectionState.isActive {
                modeBadge
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }

            // Активные сервисы
            activePresetsLabel
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: connectionVM.connectionState)
    }

    private var modeBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionVM.connectionMode == .vpn ? Color.xasuCyan : Color.xasuPurple)
                .frame(width: 5, height: 5)
                .shadow(color: connectionVM.connectionMode == .vpn ? Color.xasuCyan : Color.xasuPurple, radius: 4)

            Text(connectionVM.connectionMode.label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .liquidGlass(
            cornerRadius: 20,
            tintColor: connectionVM.connectionMode == .vpn ? .xasuCyan : .xasuPurple,
            tintOpacity: 0.07
        )
    }

    private var activePresetsLabel: some View {
        let enabled = settingsVM.presets.filter(\.isEnabled)
        let text: String
        if enabled.isEmpty         { text = "No services selected" }
        else if enabled.count == 1 { text = enabled[0].name }
        else                       { text = enabled.map(\.name).joined(separator: " · ") }

        return Text(text)
            .font(.system(size: 13, design: .rounded))
            .foregroundStyle(Color.textTertiary)
            .padding(.top, 2)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Settings
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showSettings = true
            }) {
                HStack(spacing: 7) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .medium))
                    Text("Services")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 24)
                .padding(.vertical, 13)
                .liquidGlass(cornerRadius: 22, tintColor: .white, tintOpacity: 0.03)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview { HomeView() }
