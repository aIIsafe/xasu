import SwiftUI

struct SettingsView: View {

    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AnimatedBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {

                    headerBar
                        .padding(.top, 20)

                    servicesSection

                    howItWorksSection

                    aboutSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    // MARK: - Шапка

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Services")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Choose what to unblock")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 30, height: 30)
                    .liquidGlass(cornerRadius: 15, tintColor: .white, tintOpacity: 0.04)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Сервисы

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Available services", icon: "wifi.router.fill")

            VStack(spacing: 0) {
                ForEach(Array(viewModel.presets.enumerated()), id: \.element.id) { idx, preset in
                    PresetRow(
                        preset: preset,
                        isLast: idx == viewModel.presets.count - 1,
                        onToggle: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.toggle(presetID: preset.id)
                        }
                    )
                }
            }
            .liquidGlass(cornerRadius: 20, tintColor: .white, tintOpacity: 0.03)
        }
    }

    // MARK: - Как работает

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("How Xasu works", icon: "info.circle")

            VStack(alignment: .leading, spacing: 16) {
                infoRow(icon: "1.circle.fill", color: .xasuPurple,
                        title: "Enable services above",
                        desc: "Toggle the platforms you want to access")
                Divider().background(Color.appSeparator)
                infoRow(icon: "2.circle.fill", color: .xasuCyan,
                        title: "Tap Connect on main screen",
                        desc: "Xasu creates a local VPN tunnel with DPI bypass")
                Divider().background(Color.appSeparator)
                infoRow(icon: "3.circle.fill", color: .xasuPurple,
                        title: "Works on Wi-Fi and LTE",
                        desc: "Traffic is routed through Xasu on any network interface")
            }
            .padding(16)
            .liquidGlass(cornerRadius: 20, tintColor: .white, tintOpacity: 0.02)
        }
    }

    // MARK: - О приложении

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("About Xasu", icon: "shield.lefthalf.filled")

            VStack(spacing: 0) {
                aboutRow(key: "Version",  val: "1.0.0")
                Divider().background(Color.appSeparator).padding(.leading, 16)
                aboutRow(key: "Engine",   val: "byedpi 0.17")
                Divider().background(Color.appSeparator).padding(.leading, 16)
                aboutRow(key: "Mode",     val: "VPN (SOCKS5)")
                Divider().background(Color.appSeparator).padding(.leading, 16)
                aboutRow(key: "Coverage", val: "Wi-Fi + LTE")
            }
            .liquidGlass(cornerRadius: 20, tintColor: .white, tintOpacity: 0.02)
        }
    }

    // MARK: - Утилиты

    private func sectionLabel(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.textTertiary)
            .textCase(.uppercase)
            .tracking(0.6)
            .padding(.leading, 4)
    }

    private func infoRow(icon: String, color: Color, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text(desc).font(.system(size: 13)).foregroundStyle(Color.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func aboutRow(key: String, val: String) -> some View {
        HStack {
            Text(key).font(.system(size: 15)).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(val).font(.system(size: 15, weight: .medium, design: .monospaced)).foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - PresetRow

private struct PresetRow: View {

    let preset: ServicePreset
    let isLast: Bool
    let onToggle: () -> Void

    private var accent: Color { .presetAccent(for: preset.id) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Иконка
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent.opacity(preset.isEnabled ? 0.2 : 0.08))
                        .frame(width: 42, height: 42)
                    Image(systemName: preset.systemIconName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(preset.isEnabled ? accent : Color.textTertiary)
                }
                .animation(.spring(response: 0.3), value: preset.isEnabled)

                // Текст
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Text(preset.strategyDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                }

                Spacer()

                Toggle("", isOn: Binding(get: { preset.isEnabled }, set: { _ in onToggle() }))
                    .tint(accent)
                    .labelsHidden()
            }
            .padding(.horizontal, 16).padding(.vertical, 13)

            if !isLast {
                Divider().background(Color.appSeparator).padding(.leading, 72)
            }
        }
    }
}

#Preview { SettingsView(viewModel: SettingsViewModel()) }
