// PacketTunnelProvider.swift
// XasuTunnel — Network Extension
//
// Запускает byedpi SOCKS5 прокси. Настраивает PAC-прокси через
// NEPacketTunnelNetworkSettings. При includeAllNetworks=true (задаётся
// в VPNManager) iOS сам обеспечивает работу на Wi-Fi и LTE.

import NetworkExtension
import os
import SwByeDPI

final class PacketTunnelProvider: NEPacketTunnelProvider {

    private let log = Logger(
        subsystem: "com.xasu.dpiswitch.tunnel",
        category: "XasuTunnel"
    )

    private var packetsRead = 0

    // MARK: - Старт туннеля

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        log.notice("🟣 [Xasu] Tunnel starting...")

        // Читаем аргументы из options или из App Group UserDefaults
        let argsString = (options?["xasuArgs"] as? String)
            ?? UserDefaults(suiteName: "group.com.xasu.dpiswitch")?
                .string(forKey: "xasu_combinedArgs")
            ?? ""

        let args: [String] = argsString.isEmpty
            ? ["--ip", "127.0.0.1", "--port", "10800"]
            : argsString.split(separator: " ").map(String.init)

        log.info("📋 [Xasu] byedpi args: \(args.joined(separator: " "))")

        // 1. Запускаем byedpi SOCKS5 прокси
        launchByeDPI(args: args) { [weak self] error in
            guard let self else { return }

            if let error {
                self.log.error("❌ [Xasu] byedpi launch failed: \(error.localizedDescription)")
                completionHandler(error)
                return
            }

            self.log.notice("✅ [Xasu] byedpi running on 127.0.0.1:10800")

            // 2. Применяем настройки туннеля (proxy + minimal IP)
            let settings = self.makeTunnelSettings()
            self.setTunnelNetworkSettings(settings) { settingsError in
                if let settingsError {
                    self.log.error("❌ [Xasu] setTunnelNetworkSettings: \(settingsError.localizedDescription)")
                    completionHandler(settingsError)
                    return
                }

                self.log.notice("✅ [Xasu] Tunnel active. Wi-Fi + LTE covered via proxy.")
                self.drainPacketFlow()
                completionHandler(nil)
            }
        }
    }

    // MARK: - Остановка туннеля

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        log.notice("🔴 [Xasu] Tunnel stopping. Reason=\(reason.rawValue) Packets=\(self.packetsRead)")
        _ = ByeDPI.forceStop()
        completionHandler()
    }

    // MARK: - Настройки туннеля

    private func makeTunnelSettings() -> NEPacketTunnelNetworkSettings {
        // tunnelRemoteAddress = любой адрес (для прокси-режима не важен)
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // Минимальный IPv4 — нужен чтобы extension был "активен"
        // includedRoutes пустой — трафик маршрутизируется через прокси, не через TUN
        let ipv4 = NEIPv4Settings(addresses: ["10.233.0.1"], subnetMasks: ["255.255.255.252"])
        ipv4.includedRoutes = []
        settings.ipv4Settings = ipv4

        // DNS через Google — применяется ко всем интерфейсам (Wi-Fi + LTE)
        let dns = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1", "8.8.4.4"])
        dns.matchDomains = [""]  // "" = все домены
        settings.dnsSettings = dns

        // PAC-прокси → byedpi SOCKS5 — главный механизм обхода DPI
        // Весь HTTP/HTTPS трафик идёт через byedpi, который делает TCP Split
        let proxy = NEProxySettings()
        proxy.autoProxyConfigurationEnabled = true
        proxy.proxyAutoConfigurationJavaScript = xasuPACScript
        settings.proxySettings = proxy

        return settings
    }

    /// PAC-скрипт: все запросы кроме локальных → SOCKS5 → byedpi
    private let xasuPACScript = """
    function FindProxyForURL(url, host) {
        if (isPlainHostName(host) ||
            isInNet(host, "10.0.0.0", "255.0.0.0") ||
            isInNet(host, "192.168.0.0", "255.255.0.0") ||
            isInNet(host, "127.0.0.0", "255.0.0.0")) {
            return "DIRECT";
        }
        return "SOCKS5 127.0.0.1:10800; DIRECT";
    }
    """

    // MARK: - Запуск byedpi

    private func launchByeDPI(args: [String], completion: @escaping (Error?) -> Void) {
        if ByeDPI.proxyStarted {
            _ = ByeDPI.forceStop()
        }

        var didCallback = false

        ByeDPI.start(args: args) { byeError in
            guard !didCallback else { return }
            didCallback = true
            let err = NSError(
                domain: "XasuByeDPI",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: byeError.errorDescription]
            )
            completion(err)
        }

        // Даём byedpi ~400мс чтобы запуститься
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.4) {
            guard !didCallback else { return }
            if ByeDPI.proxyStarted {
                didCallback = true
                completion(nil)
            } else {
                didCallback = true
                completion(NSError(
                    domain: "XasuByeDPI",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "byedpi did not start"]
                ))
            }
        }
    }

    // MARK: - Слив packetFlow

    // При прокси-режиме (нет IP-маршрутов) packetFlow почти пуст.
    // Читаем его чтобы буфер не блокировался на случай утечки.
    private func drainPacketFlow() {
        packetFlow.readPackets { [weak self] packets, _ in
            guard let self else { return }
            self.packetsRead += packets.count
            if self.packetsRead % 200 == 0 && self.packetsRead > 0 {
                self.log.debug("📦 [Xasu] packetFlow: \(self.packetsRead) packets drained")
            }
            self.drainPacketFlow()
        }
    }
}
