import SwiftUI

struct HomeView: View {

    @State private var settingsVM = SettingsViewModel()
    @State private var connectionVM: ConnectionViewModel
    @State private var showSettings = false
    @State private var headerScale: CGFloat = 0.85
    @State private var headerOpacity: Double = 0.0

    init() {
        let s = SettingsViewModel()
        _settingsVM = State(initialValue: s)
        _connectionVM = State(initialValue: ConnectionViewModel(settingsVM: s))
    }

    var body: some View {
        ZStack {
            AnimatedBackground()

            VStack(spacing: 0) {

                // ── Лого ──────────────────────────────────────────────
                headerView
                    .padding(.top, 64)
                    .scaleEffect(headerScale)
                    .opacity(headerOpacity)

                Spacer()

                // ── Главная кнопка ────────────────────────────────────
                ConnectButton(
                    state: connectionVM.connectionState,
                    action: { connectionVM.toggleConnection() }
                )

                // ── Статус ────────────────────────────────────────────
                statusBlock
                    .padding(.top, 32)

                Spacer()

                // ── Кнопка настроек ──────────────────────────────────
                settingsButton
                    .padding(.bottom, 52)
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
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
                headerScale = 1.0
                headerOpacity = 1.0
            }
        }
        // Синхронизируем connectionState с реальным VPN статусом
        .onChange(of: VPNManager.shared.status) { _, _ in
            connectionVM.onVPNStatusChange()
        }
    }

    // MARK: - Компоненты

    private var headerView: some View {
        VStack(spacing: 6) {
            // Логотип XASU
            Text("XASU")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.xasuCyan, Color.xasuPurple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color.xasuPurple.opacity(0.5), radius: 12)

            Text("DPI Bypass")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.textSecondary)
                .tracking(2.5)
                .textCase(.uppercase)
        }
    }

    private var statusBlock: some View {
        VStack(spacing: 8) {
            Text(connectionVM.connectionState.displayTitle)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.35), value: connectionVM.connectionState)

            if connectionVM.connectionState.isActive {
                networkBadge
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            activePresetsLabel
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: connectionVM.connectionState)
    }

    private var networkBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.xasuCyan)
                .frame(width: 6, height: 6)
                .shadow(color: Color.xasuCyan, radius: 5)
            Text("Wi-Fi · LTE protected")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .liquidGlass(cornerRadius: 20, tintColor: .xasuCyan, tintOpacity: 0.07)
    }

    private var activePresetsLabel: some View {
        let enabled = settingsVM.presets.filter(\.isEnabled)
        let text: String
        if enabled.isEmpty           { text = "No services selected" }
        else if enabled.count == 1   { text = enabled[0].name }
        else                         { text = enabled.map(\.name).joined(separator: " · ") }

        return Text(text)
            .font(.system(size: 13, weight: .regular, design: .rounded))
            .foregroundStyle(Color.textTertiary)
            .padding(.top, 2)
    }

    private var settingsButton: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showSettings = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .medium))
                Text("Services")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, 26)
            .padding(.vertical, 13)
            .liquidGlass(cornerRadius: 24, tintColor: .white, tintOpacity: 0.03)
        }
        .buttonStyle(.plain)
    }
}

#Preview { HomeView() }
