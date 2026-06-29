import Foundation
import Observation
import NetworkExtension

enum ConnectionMode {
    case vpn    // Полный VPN туннель (Wi-Fi + LTE)
    case socks  // Локальный SOCKS5 прокси (только Wi-Fi при ручной настройке)

    var label: String {
        switch self {
        case .vpn:   return "VPN • Wi-Fi + LTE"
        case .socks: return "SOCKS5 • 127.0.0.1:10800"
        }
    }
}

@Observable
final class ConnectionViewModel {

    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var connectionMode:  ConnectionMode  = .vpn
    var errorMessage: String?

    private let vpn        = VPNManager.shared
    private let socks      = ByeDPIService.shared
    private let logger     = AppLogger.shared
    private let settingsVM: SettingsViewModel

    init(settingsVM: SettingsViewModel) {
        self.settingsVM = settingsVM
        syncState()
    }

    // MARK: - Публичное API

    func toggleConnection() {
        switch connectionState {
        case .disconnected, .error: connect()
        case .connected:            disconnect()
        case .connecting:           break
        }
    }

    func onVPNStatusChange() {
        // Обновляем только если в VPN режиме
        guard connectionMode == .vpn else { return }
        connectionState = mapVPNStatus(vpn.status)
        if case .connected = connectionState {
            logger.log("VPN connected (Wi-Fi + LTE)", level: .success)
        }
    }

    // MARK: - Подключение

    private func connect() {
        connectionState = .connecting
        logger.log("Connecting... Args: \(settingsVM.combinedArgs.prefix(60))...", level: .info)

        Task { @MainActor in
            do {
                logger.log("Trying VPN mode (NEPacketTunnelProvider)...", level: .debug)
                try await vpn.start(args: settingsVM.combinedArgs)
                connectionMode = .vpn
                logger.log("VPN mode started ✓", level: .success)
            } catch {
                logger.log("VPN unavailable: \(error.localizedDescription)", level: .warning)
                logger.log("Falling back to SOCKS5 proxy mode...", level: .info)
                startSOCKSFallback()
            }
        }
    }

    private func startSOCKSFallback() {
        let dpiArgs = settingsVM.dpiArgs
        logger.log("Starting byedpi SOCKS5 on 127.0.0.1:10800", level: .debug)
        if !dpiArgs.isEmpty {
            logger.log("DPI args (validated by SBDConfig): \(dpiArgs.joined(separator: " "))", level: .debug)
        }

        socks.start(dpiArgs: dpiArgs) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.connectionState = .connected
                self.connectionMode  = .socks
                self.logger.log("SOCKS5 proxy running on 127.0.0.1:10800", level: .success)
                self.logger.log("Configure proxy: Settings → Wi-Fi → your network → Proxy → Manual", level: .info)
                self.logger.log("  Server: 127.0.0.1  Port: 10800", level: .info)
            case .failure(let msg):
                self.connectionState = .error(msg)
                self.errorMessage    = msg
                self.logger.log("SOCKS5 failed: \(msg)", level: .error)
            }
        }
    }

    // MARK: - Отключение

    private func disconnect() {
        logger.log("Disconnecting (\(connectionMode == .vpn ? "VPN" : "SOCKS"))...", level: .info)
        if connectionMode == .vpn {
            vpn.stop()
        } else {
            socks.stop()
        }
        connectionState = .disconnected
        logger.log("Disconnected", level: .info)
    }

    // MARK: - Утилиты

    private func syncState() {
        if socks.isRunning {
            connectionState = .connected
            connectionMode  = .socks
        } else {
            connectionState = mapVPNStatus(vpn.status)
        }
    }

    private func mapVPNStatus(_ status: NEVPNStatus) -> ConnectionState {
        switch status {
        case .connected:                    return .connected
        case .connecting, .reasserting:     return .connecting
        case .disconnecting, .disconnected: return .disconnected
        case .invalid:                      return .disconnected
        @unknown default:                   return .disconnected
        }
    }
}
