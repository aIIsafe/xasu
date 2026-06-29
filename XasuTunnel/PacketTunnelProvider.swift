// PacketTunnelProvider.swift
// XasuTunnel — Network Extension
//
// Запускает byedpi SOCKS5 прокси внутри extension-процесса.
// Настраивает NEPacketTunnelNetworkSettings с PAC-прокси → byedpi.
// Работает на Wi-Fi и LTE благодаря includeAllNetworks=true в VPNManager.
// Бесшовное переключение сетей через NWPathMonitor + reasserting.

import NetworkExtension
import Network
import os
import SwByeDPI

final class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - Логирование

    private let log = Logger(subsystem: "com.xasu.dpiswitch.tunnel", category: "XasuTunnel")

    // MARK: - Мониторинг сети

    private var pathMonitor: NWPathMonitor?
    private let pathQueue  = DispatchQueue(label: "xasu.path", qos: .utility)
    private var lastIface: NWInterface.InterfaceType?
    private var isReconnecting = false

    // MARK: - Статистика

    private var packetsRead = 0

    // MARK: ═══ ЖИЗНЕННЫЙ ЦИКЛ ═══

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        log.notice("🟣 [Xasu] Tunnel starting...")

        // 1. Читаем аргументы: сначала из options (переданы при старте), потом из App Group
        let argsString = (options?["xasuArgs"] as? String)
            ?? UserDefaults(suiteName: "group.com.xasu.dpiswitch")?.string(forKey: "xasu_combinedArgs")
            ?? ""

        let args = argsString.isEmpty
            ? ["--ip", "127.0.0.1", "--port", "10800"]
            : argsString.split(separator: " ").map(String.init)

        log.info("📋 [Xasu] Args: \(args.joined(separator: " "))")

        // 2. Запускаем byedpi SOCKS5 прокси
        startByeDPI(args: args) { [weak self] error in
            guard let self else { return }

            if let error {
                self.log.error("❌ [Xasu] byedpi failed: \(error.localizedDescription)")
                completionHandler(error)
                return
            }

            self.log.notice("✅ [Xasu] byedpi running on 127.0.0.1:10800")

            // 3. Применяем настройки туннеля
            let settings = self.buildSettings()
            self.setTunnelNetworkSettings(settings) { settingsError in
                if let settingsError {
                    self.log.error("❌ [Xasu] setTunnelNetworkSettings: \(settingsError.localizedDescription)")
                    completionHandler(settingsError)
                    return
                }

                self.log.notice("✅ [Xasu] Network settings applied. Tunnel is active.")
                self.startPathMonitor()
                // Читаем пакеты, чтобы буфер не переполнился
                self.drainPacketFlow()
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        log.notice("🔴 [Xasu] Tunnel stopping. Reason: \(reason.rawValue) | Packets read: \(self.packetsRead)")
        pathMonitor?.cancel()
        _ = ByeDPI.forceStop()
        completionHandler()
    }

    // MARK: ═══ НАСТРОЙКИ ТУННЕЛЯ ═══

    private func buildSettings() -> NEPacketTunnelNetworkSettings {
        // tunnelRemoteAddress = любой адрес (используется только как идентификатор)
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // ── Минимальный IPv4 (нужен чтобы extension "жил") ──────────
        let ipv4 = NEIPv4Settings(addresses: ["10.233.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = []   // Не маршрутизируем пакеты — используем прокси
        settings.ipv4Settings = ipv4

        // ── DNS — через Google (применяется ко всем интерфейсам) ────
        let dns = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1", "8.8.4.4"])
        dns.matchDomains = [""]   // "" = применять ко всем доменам
        settings.dnsSettings = dns

        // ── PAC-прокси → byedpi SOCKS5 ───────────────────────────────
        // Это главный механизм: весь HTTP/HTTPS трафик идёт через byedpi,
        // который применяет TCP Split (обход DPI) перед отправкой.
        let proxy = NEProxySettings()
        proxy.autoProxyConfigurationEnabled = true
        proxy.proxyAutoConfigurationJavaScript = xasuPAC
        settings.proxySettings = proxy

        return settings
    }

    /// PAC-файл: направляет весь HTTP/HTTPS через byedpi SOCKS5
    private let xasuPAC = """
    function FindProxyForURL(url, host) {
        // Локальные адреса — напрямую
        if (isPlainHostName(host) || isInNet(host, "10.0.0.0", "255.0.0.0") ||
            isInNet(host, "192.168.0.0", "255.255.0.0") ||
            isInNet(host, "127.0.0.0", "255.0.0.0")) {
            return "DIRECT";
        }
        // Весь остальной трафик через Xasu (byedpi SOCKS5)
        return "SOCKS5 127.0.0.1:10800; DIRECT";
    }
    """

    // MARK: ═══ BYEDPI ═══

    private func startByeDPI(args: [String], completion: @escaping (Error?) -> Void) {
        // Если уже запущен — перезапускаем
        if ByeDPI.proxyStarted { _ = ByeDPI.forceStop() }

        var errorFired = false

        ByeDPI.start(args: args) { byeError in
            guard !errorFired else { return }
            errorFired = true
            let err = NSError(
                domain: "XasuByeDPI",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: byeError.errorDescription]
            )
            completion(err)
        }

        // Даём byedpi ~400мс инициализироваться
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.4) {
            guard !errorFired else { return }
            if ByeDPI.proxyStarted {
                completion(nil)
            } else {
                completion(NSError(
                    domain: "XasuByeDPI",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "byedpi did not start in time"]
                ))
            }
        }
    }

    // MARK: ═══ БЕСШОВНОЕ ПЕРЕКЛЮЧЕНИЕ СЕТЕЙ (Wi-Fi ↔ LTE) ═══

    private func startPathMonitor() {
        pathMonitor = NWPathMonitor()
        pathMonitor?.pathUpdateHandler = { [weak self] path in
            self?.handlePath(path)
        }
        pathMonitor?.start(queue: pathQueue)
        log.info("📡 [Xasu] Path monitor started")
    }

    private func handlePath(_ path: NWPath) {
        let iface: NWInterface.InterfaceType? = {
            if path.usesInterfaceType(.wifi)     { return .wifi }
            if path.usesInterfaceType(.cellular) { return .cellular }
            return nil
        }()

        // Логируем только реальную смену интерфейса
        guard iface != lastIface, path.status == .satisfied, !isReconnecting else { return }

        log.notice("🔄 [Xasu] Network: \(self.ifaceName(lastIface)) → \(self.ifaceName(iface))")
        log.info("   Interfaces: \(path.availableInterfaces.map(\.name).joined(separator:", "))")
        lastIface = iface

        isReconnecting = true
        // `reasserting = true` — iOS не разрывает VPN-соединение приложений
        reasserting = true

        setTunnelNetworkSettings(buildSettings()) { [weak self] error in
            guard let self else { return }
            if let error {
                self.log.error("❌ [Xasu] Reconnect error: \(error.localizedDescription)")
            } else {
                self.log.notice("✅ [Xasu] Seamlessly moved to \(self.ifaceName(iface))")
            }
            self.reasserting = false
            self.isReconnecting = false
        }
    }

    // MARK: ═══ DRAIN packetFlow ═══

    // Читаем пакеты из TUN чтобы буфер не блокировался.
    // Поскольку мы используем прокси, а не маршрутизацию пакетов,
    // реального трафика через packetFlow быть не должно.
    // Но на случай утечки — дренируем.
    private func drainPacketFlow() {
        packetFlow.readPackets { [weak self] packets, protocols in
            guard let self else { return }
            self.packetsRead += packets.count
            if self.packetsRead % 200 == 0 {
                self.log.debug("📦 [Xasu] packetFlow drained: \(self.packetsRead) packets")
            }
            // Продолжаем читать
            self.drainPacketFlow()
        }
    }

    // MARK: - Утилиты

    private func ifaceName(_ t: NWInterface.InterfaceType?) -> String {
        switch t {
        case .wifi:     return "Wi-Fi"
        case .cellular: return "LTE/5G"
        default:        return "none"
        }
    }
}
