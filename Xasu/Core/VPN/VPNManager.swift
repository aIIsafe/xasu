import NetworkExtension
import os

// MARK: - VPNManager
// Управляет профилем NETunnelProviderManager.
// Общается с XasuTunnel extension через start/stop.
// Наблюдает за статусом через NEVPNStatusDidChange.

@Observable
final class VPNManager {

    // MARK: - Singleton
    static let shared = VPNManager()

    // MARK: - Публичное состояние
    private(set) var status: NEVPNStatus = .disconnected
    private(set) var errorMessage: String?

    // MARK: - Приватное
    private let log = Logger(subsystem: "com.xasu.dpiswitch", category: "VPNManager")
    private var manager: NETunnelProviderManager?

    // Bundle ID Network Extension таргета (должен совпадать с XasuTunnel target)
    private let tunnelBundleID = "com.xasu.dpiswitch.tunnel" // prefixed under com.xasu.dpiswitch

    // MARK: - Инициализация

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(statusChanged(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )
        Task { await loadManager() }
    }

    // MARK: - Публичное API

    func start(args: [String]) async throws {
        let mgr = try await getOrCreateManager()

        // Сохраняем аргументы в shared UserDefaults для extension
        let argsString = args.joined(separator: " ")
        UserDefaults.shared.combinedArgs = argsString
        log.info("🚀 Starting Xasu VPN with args: \(argsString)")

        do {
            try mgr.connection.startVPNTunnel(options: [
                "xasuArgs": argsString as NSString
            ])
        } catch {
            log.error("❌ startVPNTunnel failed: \(error.localizedDescription)")
            throw error
        }
    }

    func stop() {
        manager?.connection.stopVPNTunnel()
        log.info("🛑 Xasu VPN stopped by user")
    }

    // MARK: - Приватное

    @MainActor
    private func loadManager() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            manager = managers.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == tunnelBundleID
            })
            if let mgr = manager {
                status = mgr.connection.status
                log.info("📋 Loaded existing VPN profile, status: \(mgr.connection.status.rawValue)")
            }
        } catch {
            log.error("❌ loadAllFromPreferences: \(error.localizedDescription)")
        }
    }

    private func getOrCreateManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        let existing = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == tunnelBundleID
        })
        let mgr = existing ?? NETunnelProviderManager()
        configure(mgr)
        try await mgr.saveToPreferences()
        try await mgr.loadFromPreferences()
        self.manager = mgr
        return mgr
    }

    private func configure(_ mgr: NETunnelProviderManager) {
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = tunnelBundleID
        proto.serverAddress            = "Xasu DPI Bypass"

        // ── ПАРАМЕТРЫ ДЛЯ БЕСШОВНОГО Wi-Fi ↔ LTE ────────────────────
        // false = маршруты из PacketTunnelProvider решают что идёт через VPN.
        // true принудительно блокирует ВСЁ при смене сети, вызывая разрывы.
        proto.includeAllNetworks       = false
        // Исключаем локальную сеть (192.168.x.x) — чтобы работали принтеры/Bonjour
        proto.excludeLocalNetworks     = true
        // APNs (push-уведомления) — всегда напрямую, не через VPN
        proto.excludeAPNs              = true
        // iOS 16.4+: не блокировать сотовые сервисы при смене сети
        if #available(iOS 16.4, *) { proto.excludeAPNs = true }
        // iOS 17.4+: не блокировать связь устройства при переключении
        if #available(iOS 17.4, *) { proto.excludeDeviceCommunication = true }
        // НЕ enforceRoutes — позволяет iOS плавно переключаться между сетями
        proto.enforceRoutes            = false
        // ─────────────────────────────────────────────────────────────

        mgr.protocolConfiguration  = proto
        mgr.localizedDescription   = "Xasu"
        mgr.isEnabled              = true
    }

    @objc private func statusChanged(_ notification: Notification) {
        guard let connection = notification.object as? NEVPNConnection else { return }
        let newStatus = connection.status
        log.info("🔔 VPN status changed: \(self.statusName(newStatus))")
        Task { @MainActor in
            self.status = newStatus
            if newStatus == .disconnected {
                self.errorMessage = nil
            }
        }
    }

    private func statusName(_ s: NEVPNStatus) -> String {
        switch s {
        case .invalid:      return "invalid"
        case .disconnected: return "disconnected"
        case .connecting:   return "connecting"
        case .connected:    return "connected"
        case .reasserting:  return "reasserting"
        case .disconnecting: return "disconnecting"
        @unknown default:   return "unknown"
        }
    }
}
